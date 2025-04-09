import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyMatrixWidget extends ConsumerStatefulWidget {
  final Widget child;
  final List<Client> clients;
  final SharedPreferences store;

  const MyMatrixWidget({
    super.key,
    required this.child,
    required this.clients,
    required this.store,
  });

  @override
  ConsumerState<MyMatrixWidget> createState() => _MyMatrixWidgetState();
}

class _MyMatrixWidgetState extends ConsumerState<MyMatrixWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the clients provider with the clients passed to the widget
    ref.read(matrixClientsProvider.notifier).state = widget.clients;

    // Override the sharedPreferencesProvider with the store passed to the widget
    ProviderScope.containerOf(context).updateOverrides([
      sharedPreferencesProvider.overrideWithValue(widget.store),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Get the active client
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
      client.backgroundSync = foreground;

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
    return widget.child;
  }
}
