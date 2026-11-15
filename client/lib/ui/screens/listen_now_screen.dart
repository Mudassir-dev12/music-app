import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../player/persistence.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/album_card.dart';
import '../widgets/carousel.dart';
import '../widgets/empty_state.dart';
import '../widgets/mosaic_cover.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/section_header.dart';

final recentlyPlayedFallbackProvider =
    FutureProvider.autoDispose<List<Track>>((ref) async {
  final persistence = ref.watch(persistenceServiceProvider);
  return persistence.getRecentlyPlayed();
});

class ListenNowScreen extends ConsumerWidget {
  const ListenNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final recentAsync = ref.watch(recentProvider);
    final playlistsAsync = ref.watch(playlistsProvider);

    final settingsButton = GestureDetector(
      onTap: () => context.push('/settings'),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: tokens.accent,
        child: Icon(
          Icons.person_rounded,
          color: tokens.text,
          size: 20,
        ),
      ),
    );

    return ScreenScaffold(
      title: 'Listen Now',
      trailing: settingsButton,
      slivers: [
        // 1. Recently Played section
        recentAsync.when(
          data: (recentTracks) {
            if (recentTracks.isNotEmpty) {
              return SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: MelodiaTokens.spacingLg),
                  const SectionHeader(
                    title: 'Recently Played',
                    subtitle: 'Jump back into your recent listening',
                  ),
                  const SizedBox(height: MelodiaTokens.spacingMd),
                  AlbumCarousel(
                    children: recentTracks.map((track) {
                      return AlbumCard(
                        title: track.title,
                        subtitle: track.artist,
                        imageUrl: track.thumbnail,
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playTrack(track);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: MelodiaTokens.spacingXl),
                ]),
              );
            }

            // Fallback to local storage if API returned empty
            final fallbackAsync = ref.watch(recentlyPlayedFallbackProvider);
            return fallbackAsync.maybeWhen(
              data: (localTracks) {
                if (localTracks.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
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
                      children: localTracks.map((track) {
                        return AlbumCard(
                          title: track.title,
                          subtitle: track.artist,
                          imageUrl: track.thumbnail,
                          onTap: () {
                            ref
                                .read(playerControllerProvider.notifier)
                                .playTrack(track);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: MelodiaTokens.spacingXl),
                  ]),
                );
              },
              orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(MelodiaTokens.spacingXl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // 2. Playlists & Liked Songs section
        playlistsAsync.when(
          data: (playlists) {
            return SliverList(
              delegate: SliverChildListDelegate([
                const SectionHeader(
                  title: 'Your Playlists',
                  subtitle: 'Playlists you created and liked tracks',
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                AlbumCarousel(
                  children: [
                    // Liked Songs shortcut card
                    _buildLikedSongsCard(context, tokens),
                    // User playlists
                    ...playlists.map((pl) => _buildPlaylistCard(context, pl, tokens)),
                  ],
                ),
                const SizedBox(height: 120), // Inset for mini player
              ]),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: SizedBox.shrink(),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load playlists',
                subtitle: err.toString(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLikedSongsCard(BuildContext context, MelodiaTokens tokens) {
    return GestureDetector(
      onTap: () => context.push('/playlist/liked'),
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MosaicCover(
              coverThumbnails: [],
              size: 148,
              isLikedSongs: true,
            ),
            const SizedBox(height: MelodiaTokens.spacingSm),
            Text(
              'Liked Songs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.subhead.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Auto playlist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.footnote.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(
      BuildContext context, Playlist pl, MelodiaTokens tokens) {
    return GestureDetector(
      onTap: () => context.push('/playlist/${pl.id}'),
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MosaicCover(
              coverThumbnails: pl.coverThumbnails,
              size: 148,
            ),
            const SizedBox(height: MelodiaTokens.spacingSm),
            Text(
              pl.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.subhead.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${pl.trackCount} ${pl.trackCount == 1 ? 'song' : 'songs'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.footnote.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
