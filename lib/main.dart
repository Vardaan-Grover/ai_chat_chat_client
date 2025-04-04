import 'package:flutter/material.dart';
import 'package:ai_chat_chat_client/services/log/logging_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  LoggingService.init();

  final log = LoggingService.getLogger("Main");
  log.info("All Services Initialized");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Scaffold(),
    );
  }
}