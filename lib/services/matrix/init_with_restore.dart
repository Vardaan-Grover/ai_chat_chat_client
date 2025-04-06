import 'dart:convert';
import 'dart:ui';

import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

// import 'package:fluffychat/config/app_config.dart';
import 'client_manager.dart';
import '../platform/platform_infos.dart';

class SessionBackup {
  final String? olmAccount;
  final String accessToken;
  final String userId;
  final String homeserver;
  final String? deviceId;
  final String? deviceName;

  const SessionBackup({
    required this.olmAccount,
    required this.accessToken,
    required this.userId,
    required this.homeserver,
    required this.deviceId,
    this.deviceName,
  });

  factory SessionBackup.fromJsonString(String json) =>
      SessionBackup.fromJson(jsonDecode(json));

  factory SessionBackup.fromJson(Map<String, dynamic> json) => SessionBackup(
    olmAccount: json['olm_account'],
    accessToken: json['access_token'],
    userId: json['user_id'],
    homeserver: json['homeserver'],
    deviceId: json['device_id'],
    deviceName: json['device_name'],
  );

  Map<String, dynamic> toJson() => {
    'olm_account': olmAccount,
    'access_token': accessToken,
    'user_id': userId,
    'homeserver': homeserver,
    'device_id': deviceId,
    if (deviceName != null) 'device_name': deviceName,
  };

  @override
  String toString() => jsonEncode(toJson());
}

extension InitWithRestoreExtension on Client {
  static Logger logger = Logger('SessionBackup');

  /// Deletes a stored session backup for a specific client.
  ///
  /// This function removes any saved session information from secure storage
  /// for the specified client. Use this when logging out or clearing user data.
  ///
  /// [clientName] The name of the client whose session backup should be deleted.
  ///
  /// Returns a [Future] that completes when the deletion is done (or if no storage is available).
  static Future<void> deleteSessionBackup(String clientName) async {
    logger.info('Attempting to delete session backup for client: $clientName');
    
    // Initialize secure storage based on platform
    final storage = PlatformInfos.isMobile || PlatformInfos.isLinux
        ? const FlutterSecureStorage()
        : null;
    
    if (storage == null) {
      logger.warning('Secure storage not available on this platform, no backup to delete');
      return;
    }

    // Construct the storage key using the same pattern as in initWithRestore
    final storageKey = '${AppConfig.applicationName}_session_backup_$clientName';
    
    try {
      await storage.delete(key: storageKey);
      logger.info('Session backup for $clientName deleted successfully');
    } catch (e, s) {
      logger.severe('Failed to delete session backup', e, s);
      rethrow;
    }
  }

  /// Initializes the Matrix client, attempting to restore from a backup if initialization fails.
  ///
  /// This function tries to initialize the client normally and saves the session
  /// information to a secure storage if successful. If the initialization fails,
  /// it attempts to restore the session from a previously saved backup.
  ///
  /// [onMigration] is an optional callback that gets triggered when database migration occurs.
  ///
  /// Returns a [Future] that completes when initialization is done (either successfully or restored).
  Future<void> initWithRestore({void Function()? onMigration}) async {
    // Define storage key using application name and client name
    final storageKey = '${AppConfig.applicationName}_session_backup_$clientName';
    
    // Initialize secure storage based on platform
    final storage = PlatformInfos.isMobile || PlatformInfos.isLinux
        ? const FlutterSecureStorage()
        : null;
    
    logger.info('Starting client initialization with restore capability');

    try {
      // Attempt normal initialization
      logger.info('Attempting normal client initialization');
      await init(
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
        onInitStateChanged: (state) {
          logger.fine('Init state changed: $state');
          if (state == InitState.migratingDatabase) {
            logger.info('Database migration in progress');
            onMigration?.call();
          }
        },
      );

      // If login successful, create a session backup
      if (isLogged()) {
        final accessToken = this.accessToken;
        final homeserver = this.homeserver?.toString();
        final deviceId = deviceID;
        final userId = userID;
        
        final hasBackup = (accessToken != null &&
            homeserver != null &&
            deviceId != null &&
            userId != null);
        
        assert(hasBackup, 'Missing required session data for backup');
        
        if (hasBackup) {
          logger.info('Client initialized successfully, storing session backup');
          
          // Create and store session backup
          final backup = SessionBackup(
            olmAccount: encryption?.pickledOlmAccount,
            accessToken: accessToken,
            deviceId: deviceId,
            homeserver: homeserver,
            deviceName: deviceName,
            userId: userId,
          );
          
          await storage?.write(
            key: storageKey,
            value: backup.toString(),
          );
          logger.fine('Session backup stored successfully');
        }
      } else {
        logger.warning('Client initialized but not logged in, no backup created');
      }
    } catch (e, s) {
      logger.severe('Normal initialization failed, attempting restore', e, s);
      
      // Try to restore from backup
      final sessionBackupString = await storage?.read(key: storageKey);
      if (sessionBackupString == null) {
        logger.severe('No session backup found, cannot restore');
        rethrow;
      }

      try {
        logger.info('Restoring client from backup');
        final sessionBackup = SessionBackup.fromJsonString(sessionBackupString);
        
        // Initialize with backed up credentials
        await init(
          newToken: sessionBackup.accessToken,
          newOlmAccount: sessionBackup.olmAccount,
          newDeviceID: sessionBackup.deviceId,
          newDeviceName: sessionBackup.deviceName,
          newHomeserver: Uri.tryParse(sessionBackup.homeserver),
          newUserID: sessionBackup.userId,
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: false,
          onInitStateChanged: (state) {
            logger.fine('Restore init state changed: $state');
            if (state == InitState.migratingDatabase) {
              logger.info('Database migration during restore');
              onMigration?.call();
            }
          },
        );
        logger.info('Client restored successfully from backup');
      } catch (e, s) {
        logger.severe('Restore from backup failed', e, s);
        rethrow;
      }
    }
  }
}
