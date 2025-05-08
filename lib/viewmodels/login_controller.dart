import 'dart:async';

import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:ai_chat_chat_client/viewmodels/chat_list_controller.dart';
import 'package:ai_chat_chat_client/views/screens/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => LoginController();
}

class LoginController extends ConsumerState<Login> {
  final Logger logger = Logger('LoginViewModel');

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? usernameError;
  String? passwordError;
  bool isLoading = false;
  bool showPassword = false;
  Timer? _coolDown;

  void toggleShowPassword() {
    setState(() => showPassword = !isLoading && !showPassword);
  }

  /// Authenticates the user with the Matrix server using the provided credentials.
  ///
  /// This function validates input fields, determines the type of identifier
  /// (email, phone, or username), and attempts to authenticate with the Matrix server.
  /// It handles different authentication scenarios and provides appropriate feedback.
  void login() async {
    final matrix = ref.read(matrixServiceProvider);
    logger.info('Login attempt initiated');

    // Validate username input
    if (usernameController.text.isEmpty) {
      logger.fine('Login failed: Empty username');
      setState(() => usernameError = 'Please enter your username');
      return;
    } else {
      setState(() => usernameError = null);
    }

    // Validate password input
    if (passwordController.text.isEmpty) {
      logger.fine('Login failed: Empty password');
      setState(() => passwordError = 'Please enter your password');
      return;
    } else {
      setState(() => passwordError = null);
    }

    // Begin login process
    setState(() => isLoading = true);

    // Cancel any pending homeserver discovery to avoid conflicts
    _coolDown?.cancel();

    try {
      matrix.getLoginClient().homeserver = Uri.parse(
        'https://${AppConfig.defaultHomeserver}',
      );

      final username = usernameController.text;
      AuthenticationIdentifier identifier;

      // Determine the type of identifier based on the username format
      if (username.isEmail) {
        logger.fine('Using email identifier for authentication');
        identifier = AuthenticationThirdPartyIdentifier(
          medium: 'email',
          address: username,
        );
      } else if (username.isPhoneNumber) {
        logger.fine('Using phone number identifier for authentication');
        identifier = AuthenticationThirdPartyIdentifier(
          medium: 'msisdn',
          address: username,
        );
      } else if (username.isValidMatrixId) {
        logger.fine('Using Matrix ID identifier for authentication');
        // Extract the username part from the Matrix ID
        final localpart = username.localpart!;
        identifier = AuthenticationUserIdentifier(user: localpart);

        // Ensure we're using the correct homeserver for this Matrix ID
        await _checkWellKnown(username);
      } else {
        logger.fine('Using username identifier for authentication');
        identifier = AuthenticationUserIdentifier(user: username);
      }

      logger.info(
        'Attempting to authenticate with server: ${matrix.getLoginClient().homeserver}',
      );

      // Perform the actual login request
      await matrix.getLoginClient().login(
        LoginType.mLoginPassword,
        identifier: identifier,
        password: passwordController.text,
        initialDeviceDisplayName: PlatformInfos.clientName,
      );

      logger.info('Login successful');

      if (mounted) {
        context.go('/rooms');
      }
    } on MatrixException catch (e) {
      logger.warning('Login failed: Matrix exception: ${e.errorMessage}');
      setState(() => passwordError = e.errorMessage);
      return setState(() => isLoading = false);
    } on TimeoutException catch (e) {
      logger.severe('Login timed out: ${e.toString()}');
      setState(
        () =>
            passwordError =
                'Connection timed out. Please check your internet connection.',
      );
      return setState(() => isLoading = false);
    } catch (e) {
      logger.severe('Login failed: Unknown error: ${e.toString()}');
      setState(() => passwordError = 'Login failed: ${e.toString()}');
      return setState(() => isLoading = false);
    }

    // Reset loading state if the widget is still mounted
    if (mounted) setState(() => isLoading = false);
  }

  /// Schedules a homeserver discovery request with a cooldown period to avoid
  /// excessive API calls during rapid user input.
  ///
  /// This function implements debouncing pattern to ensure we don't make too many
  /// requests when the user is actively typing their Matrix ID. It cancels any
  /// pending request and schedules a new one after a brief delay.
  ///
  /// @param userId The Matrix user ID to check (format: @username:domain.tld)
  void checkWellKnownWithCoolDown(String userId) {
    // Skip empty userIds to avoid unnecessary processing
    if (userId.isEmpty) {
      logger.fine('Skipping well-known check for empty user ID');
      return;
    }

    logger.fine('Scheduling well-known check for: $userId');

    // Cancel any pending timer to implement debouncing
    _coolDown?.cancel();

    // Schedule a new check after cooldown period
    _coolDown = Timer(const Duration(seconds: 1), () {
      logger.fine(
        'Cooldown complete, performing well-known check for: $userId',
      );
      _checkWellKnown(userId);
    });
  }

  /// Checks the well-known information for a given Matrix user ID to determine
  /// the correct homeserver URL.
  ///
  /// This function performs a discovery process to find the appropriate homeserver
  /// for the user based on their domain. It follows the Matrix specification for
  /// server discovery via .well-known endpoints.
  ///
  /// @param userId The Matrix user ID to check (format: @username:domain.tld)
  Future<void> _checkWellKnown(String userId) async {
    final matrix = ref.read(matrixServiceProvider);

    if (mounted) {
      setState(() => usernameError = null);
    }

    // Only proceed if we have a valid Matrix ID
    if (!userId.isValidMatrixId) {
      logger.fine('Invalid Matrix ID format: $userId');
      return;
    }

    logger.info('Starting well-known discovery for domain: ${userId.domain}');

    // Store the current homeserver to revert back if needed
    final originalHomeserver = matrix.getLoginClient().homeserver;

    try {
      // Start by assuming the homeserver is at the same domain as the user ID
      var targetHomeserver = Uri.https(userId.domain!, '');
      logger.fine('Initial homeserver guess: $targetHomeserver');

      // Set to the guessed homeserver temporarily to perform well-known lookup
      matrix.getLoginClient().homeserver = targetHomeserver;

      // Try to get .well-known information
      try {
        logger.fine('Fetching well-known information from $targetHomeserver');
        final wellKnownInfo = await matrix.getLoginClient().getWellknown();

        // Use the homeserver URL from well-known if available
        final wellKnownUrl = wellKnownInfo.mHomeserver.baseUrl.toString();
        if (wellKnownUrl.isNotEmpty) {
          logger.info('Found homeserver URL in well-known: $wellKnownUrl');
          targetHomeserver = wellKnownInfo.mHomeserver.baseUrl;
        }
      } catch (e) {
        // Continue with our initial guess if well-known lookup fails
        logger.warning(
          'Well-known lookup failed: ${e.toString()}. Proceeding with initial domain guess.',
        );
      }

      // Only make changes if we have a different homeserver than before
      if (targetHomeserver != originalHomeserver) {
        logger.info('Testing homeserver at: $targetHomeserver');

        // Verify if the target is actually a Matrix homeserver
        await matrix.getLoginClient().checkHomeserver(targetHomeserver);

        if (matrix.getLoginClient().homeserver == null) {
          // The server doesn't appear to be a Matrix homeserver
          logger.warning(
            '$targetHomeserver is not a valid Matrix homeserver, reverting to $originalHomeserver',
          );
          matrix.getLoginClient().homeserver = originalHomeserver;
        } else {
          logger.info('Successfully changed homeserver to: $targetHomeserver');
        }
      } else {
        // No change needed
        logger.fine('Homeserver unchanged, staying with: $originalHomeserver');
      }

      // Update the UI if we're still mounted
      if (mounted) setState(() {});
    } catch (e) {
      // Handle any errors and revert to original homeserver
      logger.severe('Error during homeserver discovery: ${e.toString()}');
      matrix.getLoginClient().homeserver = originalHomeserver;

      if (mounted) {
        setState(
          () => usernameError = 'Server discovery failed: ${e.toString()}',
        );
      }
    }
  }

  // TODO: implement password recover functionality

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoginView(this);
}

extension on String {
  static final RegExp _phoneRegex = RegExp(
    r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$',
  );
  static final RegExp _emailRegex = RegExp(r'(.+)@(.+)\.(.+)');

  bool get isEmail => _emailRegex.hasMatch(this);

  bool get isPhoneNumber => _phoneRegex.hasMatch(this);
}
