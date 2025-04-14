import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './services/matrix/client_manager.dart';
import './services/log/logging_service.dart';
import './services/providers.dart';
import './services/matrix/matrix_providers.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggingService.init();

  final log = LoggingService.getLogger("Main");
  final store = await SharedPreferences.getInstance();
  final clients = await ClientManager.getClients(
    initialize: true,
    store: store,
  );

  log.info("Application initialized with ${clients.length} clients.");

  runApp(
    ProviderScope(
      overrides: [
        matrixClientsProvider.overrideWith((ref) => clients),
        sharedPreferencesProvider.overrideWith((ref) => store),
      ],
      child: AiChatChatApp(),
    ),
  );
}