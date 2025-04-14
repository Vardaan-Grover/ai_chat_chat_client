import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/matrix/matrix_providers.dart';
import '../config/app_routes.dart';

/// Provider for the application's router
///
/// This router is created outside the build method so that hot reload does
/// not reset the current path.
final routerProvider = Provider<GoRouter>((ref) {
  // Get the Matrix client
  final client = ref.watch(clientProvider);

  // Create the router with routes defined in AppRoutesConfig
  final router = GoRouter(
    initialLocation: '/',
    routes: AppRoutes.getRoutes(client),
    debugLogDiagnostics: true,
  );

  return router;
});
