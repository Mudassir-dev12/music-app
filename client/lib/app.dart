import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart' as config;
import 'player/history_outbox.dart';
import 'player/shortcuts.dart';
import 'session/session_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';
import 'ui/screens/album_screen.dart';
import 'ui/screens/artist_screen.dart';
import 'ui/screens/browse_screen.dart';
import 'ui/screens/download_queue_screen.dart';
import 'ui/screens/downloaded_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/listen_now_screen.dart';
import 'ui/screens/mood_playlists_screen.dart';
import 'ui/screens/now_playing_screen.dart';
import 'ui/screens/playlist_screen.dart';
import 'ui/screens/queue_panel_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/yt_playlist_screen.dart';
import 'ui/shell/adaptive_shell.dart';
import 'ui/widgets/server_url_dialog.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/listen-now',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          int index = 0;
          if (path.startsWith('/browse') || path.startsWith('/mood')) {
            index = 1;
          } else if (path.startsWith('/library') ||
              path.startsWith('/playlist') ||
              path.startsWith('/downloaded') ||
              path.startsWith('/downloads')) {
            index = 2;
          } else if (path.startsWith('/search')) {
            index = 3;
          }
          return AdaptiveShell(
            currentIndex: index,
            onTap: (i) {
              switch (i) {
                case 0:
                  context.go('/listen-now');
                  break;
                case 1:
                  context.go('/browse');
                  break;
                case 2:
                  context.go('/library');
                  break;
                case 3:
                  context.go('/search');
                  break;
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/listen-now',
            builder: (context, state) => const ListenNowScreen(),
          ),
          GoRoute(
            path: '/browse',
            builder: (context, state) => const BrowseScreen(),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/downloaded',
            builder: (context, state) => const DownloadedScreen(),
          ),
          GoRoute(
            path: '/downloads/queue',
            builder: (context, state) => const DownloadQueueScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/playlist/:id',
            builder: (context, state) => PlaylistScreen(
              playlistId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/album/:id',
            builder: (context, state) => AlbumScreen(
              albumId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/artist/:id',
            builder: (context, state) => ArtistScreen(
              artistId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/ytplaylist/:id',
            builder: (context, state) => YtPlaylistScreen(
              playlistId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/mood/:params',
            builder: (context, state) => MoodPlaylistsScreen(
              params: state.pathParameters['params']!,
              title: state.uri.queryParameters['title'] ?? 'Mood',
            ),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
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
    ref.watch(historyOutboxProvider);

    // 1. Release mode configuration guard
    if (!config.isReleaseConfigured) {
      return MaterialApp(
        title: 'Melodia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: MelodiaTokens.dark.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.settings_suggest_rounded,
                      size: 56,
                      color: MelodiaTokens.dark.accent,
                    ),
                    const SizedBox(height: MelodiaTokens.spacingLg),
                    Text(
                      'This build is not configured',
                      textAlign: TextAlign.center,
                      style: MelodiaTokens.title3.copyWith(
                        color: MelodiaTokens.dark.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: MelodiaTokens.spacingMd),
                    Text(
                      'This release build of Melodia was compiled without a production server address.\n\nPlease rebuild with:\n--dart-define=API_URL=https://music-api.yourdomain.com',
                      textAlign: TextAlign.center,
                      style: MelodiaTokens.subhead.copyWith(
                        color: MelodiaTokens.dark.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingXl),
              child: Builder(
                builder: (context) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          MelodiaTokens.dark.accent,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),
                      Text(
                        session.connectingMessage ?? 'Connecting to your music server...',
                        textAlign: TextAlign.center,
                        style: MelodiaTokens.headline.copyWith(
                          color: MelodiaTokens.dark.text,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingSm),
                      Text(
                        config.apiUrl,
                        textAlign: TextAlign.center,
                        style: MelodiaTokens.caption.copyWith(
                          color: MelodiaTokens.dark.textSecondary,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: MelodiaTokens.spacingMd,
                        runSpacing: MelodiaTokens.spacingSm,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry Now'),
                            onPressed: () {
                              ref.invalidate(sessionProvider);
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Server URL'),
                            onPressed: () => showServerUrlDialog(context, ref),
                          ),
                          TextButton(
                            child: const Text('Continue Offline'),
                            onPressed: () {
                              ref.read(sessionProvider.notifier).continueOffline();
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    if (session.error != null) {
      final err = session.error!;
      final isNetwork = err.contains('NetworkError') ||
          err.toLowerCase().contains('connection') ||
          err.toLowerCase().contains('socket') ||
          err.toLowerCase().contains('timeout');

      final displayMessage = isNetwork
          ? "Can't reach the music server. Check your connection; we'll keep trying."
          : err;

      return MaterialApp(
        title: 'Melodia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: Scaffold(
          backgroundColor: MelodiaTokens.dark.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MelodiaTokens.spacingXl,
                  vertical: MelodiaTokens.spacingLg,
                ),
                child: Builder(
                  builder: (scaffoldContext) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isNetwork
                              ? Icons.cloud_off_rounded
                              : Icons.error_outline_rounded,
                          size: 56,
                          color: MelodiaTokens.dark.accent,
                        ),
                        const SizedBox(height: MelodiaTokens.spacingLg),
                        Text(
                          isNetwork
                              ? "Can't Reach Server"
                              : 'Configuration Error',
                          textAlign: TextAlign.center,
                          style: MelodiaTokens.title3.copyWith(
                            color: MelodiaTokens.dark.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: MelodiaTokens.spacingMd),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MelodiaTokens.spacingMd,
                            vertical: MelodiaTokens.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: MelodiaTokens.dark.surface,
                            borderRadius: BorderRadius.circular(
                              MelodiaTokens.radiusCard,
                            ),
                          ),
                          child: Text(
                            config.apiUrl,
                            textAlign: TextAlign.center,
                            style: MelodiaTokens.footnote.copyWith(
                              color: MelodiaTokens.dark.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: MelodiaTokens.spacingMd),
                        Text(
                          displayMessage,
                          textAlign: TextAlign.center,
                          style: MelodiaTokens.subhead.copyWith(
                            color: MelodiaTokens.dark.textSecondary,
                          ),
                        ),
                        if (kDebugMode && !isNetwork) ...[
                          const SizedBox(height: MelodiaTokens.spacingSm),
                          Text(
                            'Host: ${Uri.tryParse(config.apiUrl)?.host ?? config.apiUrl}',
                            style: MelodiaTokens.caption.copyWith(
                              color: MelodiaTokens.dark.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(height: MelodiaTokens.spacingXl),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry Connection'),
                          onPressed: () {
                            ref.invalidate(sessionProvider);
                          },
                        ),
                        const SizedBox(height: MelodiaTokens.spacingSm),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Change Server URL'),
                          onPressed: () {
                            showServerUrlDialog(scaffoldContext, ref);
                          },
                        ),
                        const SizedBox(height: MelodiaTokens.spacingSm),
                        TextButton.icon(
                          icon: const Icon(Icons.offline_bolt_outlined, size: 18),
                          label: const Text('Continue in Offline Mode'),
                          onPressed: () {
                            ref.read(sessionProvider.notifier).continueOffline();
                          },
                        ),
                      ],
                    );
                  },
                ),
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
