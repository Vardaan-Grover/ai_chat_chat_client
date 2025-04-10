import 'package:ai_chat_chat_client/services/matrix/client_manager.dart';
import 'package:ai_chat_chat_client/services/log/logging_service.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/viewmodels/login.dart';
import 'package:ai_chat_chat_client/views/layouts/login_scaffold.dart';
import 'package:ai_chat_chat_client/views/screens/login_view.dart';
import 'package:ai_chat_chat_client/views/widgets/my_matrix_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      child: MyApp(clients: clients, store: store),
    ),
  );
}

class MyApp extends StatelessWidget {
  final List<Client> clients;
  final SharedPreferences store;

  const MyApp({super.key, required this.clients, required this.store});

  @override
  Widget build(BuildContext context) {
    return MyMatrixWidget(
      child: MaterialApp(
        title: 'AI Chat Chat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: Login(),
      ),
    );
  }
}
