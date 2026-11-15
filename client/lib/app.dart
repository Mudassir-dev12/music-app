import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'player/shortcuts.dart';
import 'session/session_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';
import 'ui/screens/auth/sign_in_screen.dart';
import 'ui/screens/auth/sign_up_screen.dart';
import 'ui/screens/browse_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/listen_now_screen.dart';
import 'ui/screens/now_playing_screen.dart';
import 'ui/screens/queue_panel_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/shell/adaptive_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/listen-now',
    redirect: (context, state) {
      if (session.isLoading) return null; // Wait for initial session restore

      final isSignedIn = session.isSignedIn;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isSignedIn && !isAuthRoute) {
        return '/auth/sign-in';
      }
      if (isSignedIn && isAuthRoute) {
        return '/listen-now';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
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
