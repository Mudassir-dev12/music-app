import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../player/persistence.dart';
import '../../player/player_controller.dart';
import '../../session/session_controller.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/album_card.dart';
import '../widgets/carousel.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/section_header.dart';

final recentlyPlayedProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final persistence = ref.watch(persistenceServiceProvider);
  return persistence.getRecentlyPlayed();
});

class ListenNowScreen extends ConsumerWidget {
  const ListenNowScreen({super.key});

  void _showProfileMenu(BuildContext context, WidgetRef ref, MelodiaTokens tokens) {
    final session = ref.read(sessionProvider);
    final user = session.user;
    final currentTheme = ref.read(themeControllerProvider).valueOrNull ?? ThemeMode.system;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MelodiaTokens.radiusSheet),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MelodiaTokens.spacingLg,
            horizontal: MelodiaTokens.spacingLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: tokens.accent,
                      child: Text(
                        (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                        style: MelodiaTokens.title3.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: MelodiaTokens.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? user.email.split('@').first,
                            style: MelodiaTokens.headline.copyWith(color: tokens.text),
                          ),
                          Text(
                            user.email,
                            style: MelodiaTokens.footnote.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MelodiaTokens.spacingLg),
                Divider(color: tokens.separator, height: 1),
                const SizedBox(height: MelodiaTokens.spacingLg),
              ],
              Text(
                'APPEARANCE',
                style: MelodiaTokens.caption.copyWith(
                  color: tokens.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: MelodiaTokens.spacingSm),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_suggest_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {currentTheme},
                onSelectionChanged: (selected) {
                  ref.read(themeControllerProvider.notifier).setTheme(selected.first);
                },
              ),
              const SizedBox(height: MelodiaTokens.spacingXl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(sessionProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.surface2,
                    foregroundColor: tokens.destructive,
                    padding: const EdgeInsets.symmetric(
                      vertical: MelodiaTokens.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final recentlyPlayedAsync = ref.watch(recentlyPlayedProvider);

    final profileButton = GestureDetector(
      onTap: () => _showProfileMenu(context, ref, tokens),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: tokens.accent,
        child: Text(
          (user?.displayName ?? user?.email ?? 'M').substring(0, 1).toUpperCase(),
          style: MelodiaTokens.footnote.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return ScreenScaffold(
      title: 'Listen Now',
      trailing: profileButton,
      slivers: [
        recentlyPlayedAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'No Recently Played Music',
                  subtitle: 'Tracks you play will appear here.',
                ),
              );
            }

            return SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: MelodiaTokens.spacingLg),
                const SectionHeader(
                  title: 'Recently Played',
                  subtitle: 'Jump back into your recent listening',
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                AlbumCarousel(
                  children: tracks.map((track) {
                    return AlbumCard(
                      title: track.title,
                      subtitle: track.artist,
                      imageUrl: track.thumbnail,
                      onTap: () {
                        ref.read(playerControllerProvider.notifier).playTrack(track);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: MelodiaTokens.spacingXl),
              ]),
            );
          },
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load tracks',
              subtitle: err.toString(),
            ),
          ),
        ),
      ],
    );
  }
}
