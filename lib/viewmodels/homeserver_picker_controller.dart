import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:ai_chat_chat_client/viewmodels/login_controller.dart';
import 'package:ai_chat_chat_client/views/screens/homeserver_picker_view.dart';
import 'package:ai_chat_chat_client/views/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeserverPicker extends ConsumerStatefulWidget {
  final bool addMultiAccount;

  const HomeserverPicker({required this.addMultiAccount, super.key});

  @override
  ConsumerState<HomeserverPicker> createState() => HomeserverPickerController();
}

class HomeserverPickerController extends ConsumerState<HomeserverPicker> {
  final Logger logger = Logger('HomeserverPickerController');

  final TextEditingController homeserverController = TextEditingController(
    text: AppConfig.defaultHomeserver,
  );

  bool isLoading = false;
  String? errorText;
  List<LoginFlow>? loginFlows;

  bool _supportsFlow(String flowType) =>
      loginFlows?.any((flow) => flow.type == flowType) ?? false;

  bool get supportsSso => _supportsFlow('m.login.sso');

  bool isDefaultPlatform =
      (PlatformInfos.isMobile || PlatformInfos.isWeb || PlatformInfos.isMacOS);

  bool get supportsPasswordLogin => _supportsFlow('m.login.password');

  /// Analyzes and validates the given homeserver URL.
  ///
  /// This function performs several steps:
  /// 1. Sanitizes the homeserver input
  /// 2. Validates and formats the homeserver URL with HTTPS
  /// 3. Checks the homeserver for available login flows
  /// 4. Initiates the appropriate login process based on available methods
  ///
  /// [legacyPasswordLogin] - When true, forces password login even if SSO is available
  ///
  /// Throws exceptions if homeserver validation fails
  Future<void> checkHomeserverAction({bool legacyPasswordLogin = false}) async {
    logger.info('Starting homeserver validation');
    setState(() => isLoading = true);

    final matrix = ref.read(matrixServiceProvider);

    // Sanitize input by removing spaces and standardizing format
    final homeserverInput = homeserverController.text
        .trim()
        .toLowerCase()
        .replaceAll(' ', '-');

    // Handle empty input case
    if (homeserverInput.isEmpty) {
      logger.info('Empty homeserver input, resetting state');
      setState(() {
        errorText = loginFlows = null;
        isLoading = false;
        matrix.getLoginClient().homeserver = null;
      });
      return;
    }

    try {
      logger.info('Validating homeserver: $homeserverInput');

      // Ensure URL has proper scheme (HTTPS)
      var homeserver = Uri.parse(homeserverInput);
      if (homeserver.scheme.isEmpty) {
        logger.info('Adding HTTPS scheme to homeserver URL');
        homeserver = Uri.https(homeserverInput, '');
      }

      // Check homeserver for valid login flows
      final client = matrix.getLoginClient();
      logger.info('Checking homeserver capabilities');
      final (_, wellKnown, loginFlows) = await client.checkHomeserver(
        homeserver,
      );

      // Store available login flows for later use
      this.loginFlows = loginFlows;
      logger.info(
        'Available login flows: ${loginFlows.map((f) => f.type).join(", ")}',
      );

      // Handle SSO login flow if available and not forcing password login
      if (supportsSso && !legacyPasswordLogin) {
        logger.info('SSO login available, proceeding with SSO flow');

        // Show consent dialog on desktop platforms
        if (!PlatformInfos.isMobile) {
          logger.info('Showing SSO consent dialog on desktop');
          final consent = await showOkCancelAlertDialog(
            context: context,
            title: 'Use $homeserverInput to login',
            message:
                'You hereby allow the app and website to share information about you.',
            okLabel: 'Continue',
          );

          if (consent != OkCancelResult.ok) {
            logger.info('User declined SSO consent');
            setState(() => isLoading = false);
            return;
          }
        }

        // Proceed with SSO login
        return ssoLoginAction();
      }

      // Fall back to password login
      logger.info('Proceeding with password login flow');

      // TODO: replace with gorouter implementation
      setState(() => errorText = null);
      Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => Login()));
    } catch (e) {
      logger.warning('Homeserver validation failed: $e');
      setState(() => errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        logger.info('Homeserver validation completed');
      }
    }
  }

  /// Initiates a Single Sign-On (SSO) authentication flow through the Matrix protocol.
  ///
  /// This function:
  /// 1. Constructs an appropriate redirect URL based on platform
  /// 2. Opens a web authentication flow for the user to complete SSO
  /// 3. Processes the returned login token
  /// 4. Completes authentication with the Matrix server
  ///
  /// The function handles different platform requirements and provides
  /// comprehensive error reporting through the UI and logs.
  Future<void> ssoLoginAction() async {
    logger.info('Starting SSO authentication flow');

    try {
      final matrix = ref.read(matrixServiceProvider);

      // Determine appropriate redirect URL based on platform capabilities
      final redirectUrl =
          isDefaultPlatform
              ? '${AppConfig.appOpenUrlScheme.toLowerCase()}://login'
              : 'http://localhost:3000/login'; // Note: Fixed extra slash in URL

      logger.info('Using redirect URL: $redirectUrl');

      // Construct the SSO URL with the Matrix server
      final homeserver = matrix.getLoginClient().homeserver;
      if (homeserver == null) {
        logger.warning('Attempted SSO login with null homeserver');
        setState(() => errorText = 'No homeserver selected');
        return;
      }

      final url = homeserver.replace(
        path: '/_matrix/client/v3/login/sso/redirect',
        queryParameters: {'redirectUrl': redirectUrl},
      );

      logger.info('Opening SSO authentication URL: ${url.toString()}');

      // Determine URL scheme for callback based on platform
      final urlScheme =
          isDefaultPlatform
              ? Uri.parse(redirectUrl).scheme
              : 'http://localhost:3000';

      // Present authentication interface to user
      setState(() => isLoading = true);

      // Launch the web authentication flow
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: urlScheme,
        options: const FlutterWebAuth2Options(),
      );

      logger.info('Received callback from SSO provider');

      // Extract login token from the callback URL
      final token = Uri.parse(result).queryParameters['loginToken'];
      if (token == null || token.isEmpty) {
        logger.warning('Received empty or null login token from SSO provider');
        setState(() {
          errorText = 'Invalid or missing authentication token';
          isLoading = false;
        });
        return;
      }

      logger.info(
        'Successfully obtained login token, proceeding with Matrix authentication',
      );

      // Reset any previous errors and show loading state
      setState(() {
        errorText = null;
        isLoading = true;
      });

      // Complete the Matrix login flow with the token
      await matrix.getLoginClient().login(
        LoginType.mLoginToken,
        token: token,
        initialDeviceDisplayName: PlatformInfos.clientName,
      );

      logger.info('SSO authentication completed successfully');

      // TODO: Navigation to next screen should happen here or through a state management system monitoring logged-in state
    } catch (e, stackTrace) {
      logger.severe('SSO authentication failed', e, stackTrace);
      setState(() => errorText = 'Authentication error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> restoreBackup() async {
    // TODO: Implement restore backup functionality
  }

  void onMoreAction(MoreLoginActions action) {
    switch (action) {
      case MoreLoginActions.importBackup:
        restoreBackup();
      case MoreLoginActions.privacy:
        launchUrlString(AppConfig.privacyUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeserverPickerView(this);
  }
}

enum MoreLoginActions { importBackup, privacy }

class IdentityProvider {
  final String? id;
  final String? name;
  final String? icon;
  final String? brand;

  IdentityProvider({this.id, this.name, this.icon, this.brand});

  factory IdentityProvider.fromJson(Map<String, dynamic> json) =>
      IdentityProvider(
        id: json['id'],
        name: json['name'],
        icon: json['icon'],
        brand: json['brand'],
      );
}
