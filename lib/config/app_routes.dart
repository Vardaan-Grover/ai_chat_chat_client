import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../services/theme/themes.dart';
import '../views/layouts/empty_page.dart';
import '../views/layouts/three_column_layout.dart';
import '../viewmodels/chat_list_controller.dart';
import '../viewmodels/login_controller.dart';

/// Defines the application's routing configuration
abstract class AppRoutes {
  /// Creates routes for the application
  static List<RouteBase> getRoutes(Client client) {
    return [
      GoRoute(path: '/', redirect: (_, __) => '/login'),
      GoRoute(
        path: '/login',
        name: 'login',
        redirect: (context, state) => _loggedInRedirect(context, state, client),
        pageBuilder:
            (context, state) =>
                _defaultPageBuilder(context, state, const Login()),
      ),
      ShellRoute(
        // Never use a transition on the shell route. Changing the PageBuilder
        // here based on a MediaQuery causes child to be briefly rendered twice with the same GlobalKey
        pageBuilder:
            (context, state, child) => _noTransitionPageBuilder(
              context,
              state,
              AIChatChatThemes.isColumnMode(context) &&
                      state.fullPath?.startsWith('/rooms/settings') == false
                  ? ThreeColumnLayout(
                    leftSideView: ChatList(
                      activeChat: state.pathParameters['roomId'],
                    ),
                    mainView: child,
                    rightSideView: const SizedBox.shrink(
                      child: Text('Right Side Widget'),
                    ),
                  )
                  : child,
            ),
        routes: [
          GoRoute(
            path: '/rooms',
            name: 'rooms',
            redirect:
                (context, state) => _loggedOutRedirect(context, state, client),
            pageBuilder:
                (context, state) => _defaultPageBuilder(
                  context,
                  state,
                  AIChatChatThemes.isColumnMode(context)
                      ? const EmptyPage()
                      : ChatList(activeChat: state.pathParameters['roomId']),
                ),
            routes: [
              GoRoute(
                path: ':roomId',
                name: 'room',
                redirect:
                    (context, state) =>
                        _loggedOutRedirect(context, state, client),
                pageBuilder: (context, state) {
                  // TODO: implement the page builder for this route
                  return _defaultPageBuilder(
                    context,
                    state,
                    const EmptyPage(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ];
  }

  /// Redirect logged-in users to rooms
  static FutureOr<String?> _loggedInRedirect(
    BuildContext context,
    GoRouterState state,
    Client client,
  ) => client.isLogged() ? '/rooms' : null;

  /// Redirect logged-out users to login
  static FutureOr<String?> _loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
    Client client,
  ) => client.isLogged() ? null : '/login';

  /// Creates a page with no transition animation
  static Page _noTransitionPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => NoTransitionPage(
    key: state.pageKey,
    restorationId: state.pageKey.value,
    child: child,
  );

  /// Creates a default page based on layout mode
  static Page _defaultPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) =>
      AIChatChatThemes.isColumnMode(context)
          ? _noTransitionPageBuilder(context, state, child)
          : MaterialPage(
            key: state.pageKey,
            restorationId: state.pageKey.value,
            child: child,
          );
}
