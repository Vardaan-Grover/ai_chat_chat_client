import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_chat_chat_client/services/matrix/matrix_file_extension.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/future_loading_dialog.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import './account_bundle.dart';
import './client_manager.dart';
import './init_with_restore_extension.dart';
import '../platform/platform_infos.dart';
import './uia_request_manager.dart';

import 'package:collection/collection.dart';
import 'package:cross_file/cross_file.dart';
import 'package:logging/logging.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for managing Matrix clients and their states.
///
/// This is the core service that handles:
/// - Client lifecycle management
/// - Account bundles organization
/// - Event subscriptions
/// - Verification requests
/// - Login state tracking
class MatrixService {
  /// Logger instance for this service
  static final Logger logger = Logger('MatrixService');

  // Dependencies
  final SharedPreferences store;
  final StateController<List<Client>> clientsNotifier;
  final StateController<int> activeClientIndexNotifier;
  final StateController<String?> activeBundleNotifier;

  // Client and bundle tracking
  int get activeClientIndex => activeClientIndexNotifier.state;
  set activeClientIndex(int value) => activeClientIndexNotifier.state = value;

  String? get activeBundle => activeBundleNotifier.state;
  set activeBundle(String? value) => activeBundleNotifier.state = value;

  List<Client> get clients => clientsNotifier.state;
  set clients(List<Client> value) => clientsNotifier.state = value;

  // Login state variables
  XFile? loginAvatar;
  String? loginUsername;
  bool? loginRegistrationSupported;

  // Verification Credentials
  late String currentClientSecret;
  RequestTokenResponse? currentThreepidCreds;

  // Subscription management
  final onRoomKeyRequestSub = <String, StreamSubscription>{};
  final onKeyVerificationRequestSub = <String, StreamSubscription>{};
  final onNotification = <String, StreamSubscription>{};
  final onLoginStateChanged = <String, StreamSubscription<LoginState>>{};
  final onUiaRequest = <String, StreamSubscription<UiaRequest>>{};

  // Password Caching
  Client? _loginClientCandidate;
  String? _cachedPassword;
  Timer? _cachedPasswordClearTimer;

  /// Gets or sets the cached password
  ///
  /// The cached password is automatically cleared after 10 minutes.
  String? get cachedPassword => _cachedPassword;
  set cachedPassword(String? p) {
    logger.fine("Password cached");
    _cachedPasswordClearTimer?.cancel();
    _cachedPassword = p;
    _cachedPasswordClearTimer = Timer(const Duration(minutes: 10), () {
      _cachedPassword = null;
      logger.fine("Cached password cleared");
    });
  }

  MatrixService(
    this.store,
    this.clientsNotifier,
    this.activeBundleNotifier,
    this.activeClientIndexNotifier,
  ) {
    logger.info("Initializing MatrixService");
    currentClientSecret = DateTime.now().millisecondsSinceEpoch.toString();
    // Initialize MatrixService
    _initMatrix();
  }

  /// Returns the currently active client
  Client get client {
    if (clients.isEmpty) {
      logger.info("No clients available, creating a login client");
      clientsNotifier.state = [...clients, getLoginClient()];
    }

    if (activeClientIndex < 0 || activeClientIndex >= clients.length) {
      logger.warning(
        "Invalid active client index, using the first client from the bundle",
      );
      return currentBundle!.first!;
    }

    return clients[activeClientIndex];
  }

  /// Returns whether multiple accounts are enabled
  bool get isMultiAccount => clients.length > 1;

  /// Gets the index of a client by its Matrix ID
  ///
  /// Returns -1 if no client is found with the given Matrix ID.
  int getClientIndexByMatrixId(String matrixId) {
    final index = clients.indexWhere((client) => client.userID == matrixId);
    logger.fine('Found client index $index for Matrix ID $matrixId');
    return index;
  }

  /// Sets a client as the active client
  ///
  /// If the client is found in the list of clients, updates the active index.
  /// Otherwise, logs a warning.
  void setActiveClient(Client? cl) {
    if (cl == null) {
      logger.warning('Attempted to set null client as active');
      return;
    }

    final i = clients.indexWhere((c) => c == cl);
    if (i != -1) {
      logger.info('Setting client ${cl.userID} as active (index: $i)');
      activeClientIndex = i;
      // TODO: Implement VoIP plugin creation if needed
    } else {
      logger.warning('Tried to set an unknown client ${cl.userID} as active');
    }
  }

  /// Gets a client by its name
  ///
  /// Returns null if no client is found with the given name.
  Client? getClientByName(String name) {
    final client = clients.firstWhereOrNull((c) => c.clientName == name);
    if (client == null) {
      logger.fine('No client found with name: $name');
    }
    return client;
  }

  /// Gets all account bundles
  ///
  /// Creates a map of bundle names to lists of clients that belong to that bundle.
  /// Sorts clients within each bundle by priority
  Map<String?, List<Client?>> get accountBundles {
    final resBundles = <String?, List<_AccountBundleWithClient>>{};

    for (var i = 0; i < clients.length; i++) {
      final bundles = clients[i].accountBundles;
      for (final bundle in bundles) {
        if (bundle.name == null) {
          continue;
        }

        resBundles[bundle.name] ??= [];
        resBundles[bundle.name]!.add(
          _AccountBundleWithClient(client: clients[i], bundle: bundle),
        );
      }
    }

    // Sort bundles by priority
    for (final b in resBundles.values) {
      b.sort(
        (a, b) =>
            a.bundle!.priority == null
                ? 1
                : b.bundle!.priority == null
                ? -1
                : a.bundle!.priority!.compareTo(b.bundle!.priority!),
      );
    }

    // Convert to map of bundle names to clients
    return resBundles.map(
      (k, v) => MapEntry(k, v.map((vv) => vv.client).toList()),
    );
  }

  /// Indicates whether there are complex bundles of accounts
  ///
  /// A complex bundle is when a bundle contains multiple clients.
  bool get hasComplexBundles => accountBundles.values.any((v) => v.length > 1);

  /// Gets the current bundle of clients
  ///
  /// If there are no complex bundles, returns all clients.
  /// Otherwise, returns the clients in the active bundle or the first bundle.
  List<Client?>? get currentBundle {
    if (!hasComplexBundles) {
      logger.fine("No complex bundles, returning all clients");
      return clients;
    }

    final bundles = accountBundles;
    if (bundles.containsKey(activeBundle)) {
      logger.fine("Returning clients from active bundle: $activeBundle");
      return bundles[activeBundle];
    }

    logger.fine("No active bundle, returning first bundle");
    return bundles.values.first;
  }

  /// Gets or creates a client for login purposes
  ///
  /// This function manages the lifecycle of login clients:
  /// - Reuses existing non-logged-in clients when available
  /// - Creates new clients when needed with proper naming
  /// - Sets up login state change handlers
  /// - Manages client registration in the global client list
  ///
  /// @return A Matrix client ready for login operations
  Client getLoginClient() {
    // Try to use an existing non-logged in client
    if (clients.isNotEmpty && !client.isLogged()) {
      logger.info("Using existing non-logged-in client for login");
      return client;
    }

    // Create a new client if needed or use the existing login candidate
    logger.info("Creating new login client for authentication");

    // Use existing candidate or create a new one with a unique timestamp-based name
    final candidate =
        _loginClientCandidate ??= ClientManager.createClient(
          '${AppConfig.applicationName}-${DateTime.now().millisecondsSinceEpoch}',
          store,
        );

    // Set up login state change subscription to handle successful login
    candidate.onLoginStateChanged.stream
        .where((l) => l == LoginState.loggedIn)
        .first
        .then((_) async {
          logger.info("Login successful for client: ${candidate.clientName}");

          // Add the client to the managed clients list if not already present
          if (!clients.contains(candidate)) {
            logger.info("Adding newly logged in client to clients list");
            clients = [...clients, candidate];
          }

          // Persist the client name in the store for future app sessions
          logger.info(
            "Persisting client configuration in store: ${candidate.clientName}",
          );
          await ClientManager.addClientNameToStore(candidate.clientName, store);

          // Register all required event subscriptions for this client
          logger.info(
            "Registering event subscriptions for: ${candidate.clientName}",
          );
          _registerSubs(candidate.clientName);

          // Clear the login candidate reference after successful processing
          logger.fine("Clearing login candidate reference");
          _loginClientCandidate = null;

          // TODO: Navigate to rooms screen using navigation system
          logger.info(
            "Login sequence complete, ready for navigation to rooms screen",
          );
        });

    logger.fine("Returning login client candidate");
    return candidate;
  }

  /// Initializes the MatrixService
  ///
  /// Sets up event subscriptions for all clients.
  void _initMatrix() {
    logger.info('Initializing Matrix Service with ${clients.length} clients');

    for (final c in clients) {
      logger.fine("Registering subscriptions client: ${c.clientName}");
      _registerSubs(c.clientName);
    }

    // TODO: Initialize background push notifications for mobile (and possibly desktop platforms)

    logger.info("Matrix service initialization complete");
  }

  /// Registers all event subscriptions for a client
  ///
  /// Sets up subscriptions for:
  /// - Room key requests
  /// - Key verification requests
  /// - Notifications
  /// - Login state changes
  /// - User interaction requests
  void _registerSubs(String name) {
    final c = getClientByName(name);

    if (c == null) {
      logger.warning("Client not found for name: $name");
      return;
    }

    logger.fine("Registering subscriptions for client: $name");

    // Room key requests
    onRoomKeyRequestSub[name] ??= c.onRoomKeyRequest.stream.listen(
      (request) => _handleRoomKeyRequest(request),
    );

    // Key verification requests
    onKeyVerificationRequestSub[name] ??= c.onKeyVerificationRequest.stream
        .listen((request) => _handleKeyVerificationRequest(request));

    // Login state changes
    onLoginStateChanged[name] ??= c.onLoginStateChanged.stream.listen(
      (state) => _handleLoginStateChanged(c, state),
    );

    // UIA requests
    onUiaRequest[name] ??= c.onUiaRequest.stream.listen(uiaRequestHandler);

    // TODO: Notification subscription pending

    logger.fine("All subscriptions registered for client: $name");
  }

  /// Cancels all subscriptions for a client
  void _cancelSubs(String name) {
    logger.fine("Cancelling subscriptions for client: $name");

    onRoomKeyRequestSub[name]?.cancel();
    onRoomKeyRequestSub.remove(name);

    onKeyVerificationRequestSub[name]?.cancel();
    onKeyVerificationRequestSub.remove(name);

    onLoginStateChanged[name]?.cancel();
    onLoginStateChanged.remove(name);

    onUiaRequest[name]?.cancel();
    onUiaRequest.remove(name);

    logger.fine("All subscriptions cancelled for client: $name");
  }

  /// Handles room key requests
  ///
  /// Processes incoming key requests from other devices/sessions.
  void _handleRoomKeyRequest(RoomKeyRequest request) async {
    logger.fine("Received room key request: $request");

    if (clients.any(
      (cl) =>
          cl.userID == request.requestingDevice.userId &&
          cl.identityKey == request.requestingDevice.curve25519Key,
    )) {
      logger.info(
        '[Key Request] Request is from one of our own clients, forwarding the key...',
      );
      await request.forwardKey();
    }
  }

  /// Handles key verification requests
  ///
  /// Processes incoming verification requests from other devices/sessions.
  void _handleKeyVerificationRequest(KeyVerification request) {
    logger.fine("Received key verification request: $request");

    var hidePopup = false;
    request.onUpdate = () {
      if (!hidePopup &&
          {
            KeyVerificationState.done,
            KeyVerificationState.error,
          }.contains(request.state)) {
        logger.warning(
          "A dialog box/popup will be shown here for verification",
        );
        // TODO: Implement popup for verification
      }
      hidePopup = true;
    };
    request.onUpdate = null;
    hidePopup = true;
    // TODO: Implement key verification dialog
  }

  /// Handles login state changes
  ///
  /// Updates the UI and state based on login/logout events.
  void _handleLoginStateChanged(Client c, LoginState state) {
    logger.info('Login state changed for ${c.clientName}: $state');
    if (state == LoginState.loggedOut) {
      logger.fine("Client logged out, deleting session backup");
      InitWithRestoreExtension.deleteSessionBackup(c.clientName);
    }
    if (isMultiAccount && state != LoginState.loggedIn) {
      logger.fine("Client logged out, removing from clients list");
      logger.finer("Client logged out, cancelling subscriptions");
      _cancelSubs(c.clientName);
      logger.finer("Removing client from provider");
      clients = clients.where((cl) => cl.clientName != c.clientName).toList();
      logger.finer("Removing client from store");
      ClientManager.removeClientNameFromStore(c.clientName, store);
      // TODO: Implement UI change to show snackbar and do rerouting

      if (state != LoginState.loggedIn) {
        // TODO: Route back to the rooms view/screen
      }
    } else {
      // TODO: If state == LoginState.loggedIn, go to rooms view/screen, else go to home view/screen
    }
  }

  Future<void> dehydrateAction(BuildContext context) async {
    final response = await showOkCancelAlertDialog(
      context: context,
      title: 'Export session and wipe device?',
      message:
          'This action cannot be undone. Ensure you safely store the backup file',
    );
    if (response != OkCancelResult.ok) {
      logger.info("User cancelled the dehydrate action");
      return;
    }
    final result = await showFutureLoadingDialog(
      context: context,
      future: client.exportDump,
    );
    final export = result.result;
    if (export == null) {
      logger.warning("Failed to export session dump");
      return;
    }

    final exportBytes = Uint8List.fromList(const Utf8Codec().encode(export));

    final exportFileName =
        'ai-chat-chat-export-${DateFormat(DateFormat.YEAR_MONTH_DAY).format(DateTime.now())}.aichatchatbackup';

    final file = MatrixFile(bytes: exportBytes, name: exportFileName);
    file.save(context);
  }

  void dispose() {
    logger.info("Disposing MatrixService");
    for (final c in clients) {
      _cancelSubs(c.clientName);
    }
    onRoomKeyRequestSub.clear();
    onKeyVerificationRequestSub.clear();
    onNotification.clear();
    onLoginStateChanged.clear();
    onUiaRequest.clear();
  }
}

class _AccountBundleWithClient {
  final Client? client;
  final AccountBundle? bundle;

  _AccountBundleWithClient({this.client, this.bundle});

  @override
  String toString() {
    return 'AccountBundleWithClient{client: $client, bundle: $bundle}';
  }
}
