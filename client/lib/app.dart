import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'player/history_outbox.dart';
import 'player/shortcuts.dart';
import 'session/session_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';
import 'ui/screens/browse_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/listen_now_screen.dart';
import 'ui/screens/now_playing_screen.dart';
import 'ui/screens/playlist_screen.dart';
import 'ui/screens/queue_panel_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/shell/adaptive_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/listen-now',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/listen-now',
                builder: (context, state) => const ListenNowScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse',
                builder: (context, state) => const BrowseScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/now-playing',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: NowPlayingScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/queue',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: QueuePanelScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/playlist/:id',
        builder: (context, state) => PlaylistScreen(
          playlistId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class MelodiaApp extends ConsumerWidget {
  const MelodiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeControllerProvider);
    final themeMode = themeAsync.valueOrNull ?? ThemeMode.system;
    final router = ref.watch(routerProvider);
    final session = ref.watch(sessionProvider);
    ref.watch(historyOutboxProvider);

    if (session.isLoading) {
      return MaterialApp(
        title: 'Melodia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: Scaffold(
          backgroundColor: MelodiaTokens.dark.background,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                MelodiaTokens.dark.accent,
              ),
            ),
          ),
        ),
      );
    }

    if (session.error != null) {
      return MaterialApp(
        title: 'Melodia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: Scaffold(
          backgroundColor: MelodiaTokens.dark.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: MelodiaTokens.dark.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Error',
                    style: TextStyle(
                      color: MelodiaTokens.dark.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MelodiaTokens.dark.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(sessionProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MelodiaShortcuts(
      child: MaterialApp.router(
        title: 'Melodia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
