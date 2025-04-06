import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart' as logging;
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'custom_http_client.dart';
import 'init_with_restore.dart';
import '../db/database_builder.dart';
import '../platform/platform_infos.dart';

class ClientManager {
  static final logging.Logger logger = logging.Logger('ClientManager');
  static final String clientNamespace =
      PlatformInfos.isReleaseMode
          ? 'im.our_company_name.our_app_name.store.clients'
          : 'im.our_company_name.our_app_name.debug.store.clients';

  /// Adds a new Matrix client name to the shared preferences store.
  ///
  /// This method adds the provided [clientName] to the list of stored client names
  /// in the application's shared preferences. If the list doesn't exist yet,
  /// a new one is created.
  ///
  /// @param clientName The name of the client to add to the store
  /// @param store SharedPreferences instance to persist the client names
  /// @return A Future that completes when the operation is finished
  static Future<void> addClientNameToStore(
    String clientName,
    SharedPreferences store,
  ) async {
    logger.info('Adding client name to store: $clientName');
    
    // Get the current list of client names or create a new one if it doesn't exist
    final clientNamesList = store.getStringList(clientNamespace) ?? [];
    
    // Add the new client name to the list
    clientNamesList.add(clientName);
    logger.fine('Updated client list size: ${clientNamesList.length}');
    
    // Save the updated list back to shared preferences
    await store.setStringList(clientNamespace, clientNamesList);
    logger.fine('Client name successfully added to store');
  }

  /// Removes a Matrix client name from the shared preferences store.
  ///
  /// This method removes the specified [clientName] from the list of stored client names
  /// in the application's shared preferences. If the client name doesn't exist
  /// in the list, no changes are made.
  ///
  /// @param clientName The name of the client to remove from the store
  /// @param store SharedPreferences instance that contains the client names
  /// @return A Future that completes when the operation is finished
  static Future<void> removeClientNameFromStore(
    String clientName,
    SharedPreferences store,
  ) async {
    logger.info('Removing client name from store: $clientName');
    
    // Get the current list of client names or create a new one if it doesn't exist
    final clientNamesList = store.getStringList(clientNamespace) ?? [];
    final previousLength = clientNamesList.length;
    
    // Remove the specified client name from the list
    clientNamesList.remove(clientName);
    
    // Check if the client was actually removed
    if (previousLength != clientNamesList.length) {
      logger.fine('Client name was found and removed');
    } else {
      logger.warning('Client name $clientName was not found in the store');
    }
    
    // Save the updated list back to shared preferences
    await store.setStringList(clientNamespace, clientNamesList);
    logger.fine('Updated client list size: ${clientNamesList.length}');
  }

  /// Retrieves all Matrix clients from storage and optionally initializes them.
  ///
  /// This function performs the following steps:
  /// 1. Initializes SQLite for desktop platforms if needed
  /// 2. Retrieves client names from shared preferences
  /// 3. Creates a default client if none exists
  /// 4. Creates and optionally initializes client instances
  /// 5. Removes logged out clients if multi-account is enabled
  ///
  /// @param initialize Whether to initialize the clients after creation
  /// @param store SharedPreferences instance to retrieve client names
  /// @return A list of Matrix client instances
  static Future<List<Client>> getClients({
    bool initialize = true,
    required SharedPreferences store,
  }) async {
    logger.info('Getting Matrix clients (initialize=$initialize)');

    // Initialize SQLite for desktop platforms only
    if (!PlatformInfos.isWeb && PlatformInfos.isDesktop) {
      logger.fine('Initializing SQLite FFI for desktop platform');
      try {
        sqfliteFfiInit();
        logger.fine('SQLite FFI initialized successfully');
      } catch (e, s) {
        logger.severe('Failed to initialize sqflite_ffi', e, s);
        throw Exception('Failed to initialize sqflite_ffi: $e');
      }
    }

    // Retrieve stored client names from shared preferences
    final clientNames = <String>{};
    try {
      final clientNamesList = store.getStringList(clientNamespace) ?? [];
      clientNames.addAll(clientNamesList);
      logger.fine('Retrieved ${clientNames.length} client names from storage');
    } catch (e, s) {
      logger.severe('Client names in store are corrupted - resetting', e, s);
      await store.remove(clientNamespace);
    }

    // Create a default client if no clients exist
    if (clientNames.isEmpty) {
      const defaultClientName = 'MyAIChatChatApp';
      logger.info(
        'No clients found, creating default client: $defaultClientName',
      );
      clientNames.add(defaultClientName);
      await store.setStringList(clientNamespace, clientNames.toList());
    }

    // Create client instances for each name
    logger.fine('Creating ${clientNames.length} client instances');
    final clients = clientNames.map((name) => createClient(name)).toList();

    // Initialize clients if requested
    if (initialize) {
      logger.fine('Initializing ${clients.length} clients');
      await Future.wait(
        clients.map((client) async {
          logger.fine('Initializing client: ${client.clientName}');
          return client.initWithRestore();
        }),
      );
    }

    // Clean up logged out clients if multiple accounts exist
    if (clients.length > 1) {
      final loggedOutClients =
          clients.where((client) => !client.isLogged()).toList();

      if (loggedOutClients.isNotEmpty) {
        logger.info(
          'Found ${loggedOutClients.length} logged out clients to remove',
        );

        for (final client in loggedOutClients) {
          logger.info(
            'Removing logged out client ${client.clientName} (${client.userID})',
          );
          clientNames.remove(client.clientName);
          clients.remove(client);
        }

        // Update stored client names
        await store.setStringList(clientNamespace, clientNames.toList());
        logger.fine(
          'Updated client list in storage, remaining: ${clients.length}',
        );
      }
    }

    logger.info('Returning ${clients.length} Matrix clients');
    return clients;
  }

  static Client createClient(String name) {
    // TODO: shareKeysWith implementation pending

    return Client(
      name,
      databaseBuilder: matrixSdkDatabaseBuilder,
      importantStateEvents: <String>{'im.ponies.room_emotes'},
      verificationMethods: {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
      },
      supportedLoginTypes: {
        AuthenticationTypes.password,
        AuthenticationTypes.sso,
        AuthenticationTypes.oauth2,
      },
      httpClient: PlatformInfos.isAndroid ? CustomHttpClient.createHTTPClient() : null,
      defaultNetworkRequestTimeout: const Duration(minutes: 30),
      enableDehydratedDevices: true,
      nativeImplementations: NativeImplementationsIsolate(compute),
    );
  }
}
