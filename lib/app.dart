import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:matrix/matrix.dart';

class AIChatChatApp extends ConsumerStatefulWidget {
  const AIChatChatApp({super.key});

  @override
  ConsumerState<AIChatChatApp> createState() => _AIChatChatAppState();
}

class _AIChatChatAppState extends ConsumerState<AIChatChatApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Get the active client from the provider
    final client = ref.read(clientProvider);

    // Determine if the app is in the foreground
    final foreground =
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused;

    // Update presence based on app state
    client.syncPresence =
        state == AppLifecycleState.resumed ? null : PresenceType.unavailable;

    // Configure sync behavior for mobile platforms
    if (PlatformInfos.isMobile) {
      // Disable background sync when app is in foreground
      client.backgroundSync = !foreground;

      // Only request history on limited timeline when in background
      client.requestHistoryOnLimitedTimeline = !foreground;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Welcome to AI Chat Chat!')),
      ),
    );
  }
}
