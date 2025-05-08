import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'services/theme/themes.dart';
import 'views/widgets/custom_scroll_behavior.dart';
import 'views/widgets/my_matrix_widget.dart';
import 'views/widgets/theme_builder.dart';
import 'services/router_provider.dart';

class AiChatChatApp extends ConsumerWidget {
  const AiChatChatApp({super.key});

  /// getInitialLink may rereturn the value multiple times if this view is
  /// opened multiple times for example if the user logs out after they logged
  /// in with qr code or magic link.
  static bool gotInitialLink = false;

  // Router must be outside of build method so that hot reload does not reset
  // the current path.
  // static final GoRouter router = GoRouter(
  //   routes: AppRoutes.routes,
  //   debugLogDiagnostics: true,
  // );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return ThemeBuilder(
      builder:
          (context, themeMode, primaryColor) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: AppConfig.applicationName,
            themeMode: themeMode,
            theme: AIChatChatThemes.buildTheme(
              context,
              Brightness.light,
              primaryColor,
            ),
            darkTheme: AIChatChatThemes.buildTheme(
              context,
              Brightness.dark,
              primaryColor,
            ),
            scrollBehavior: CustomScrollBehavior(),
            routerConfig: router,
            builder: (context, child) => MyMatrixWidget(child: child),
          ),
    );
  }
}
