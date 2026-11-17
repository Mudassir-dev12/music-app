import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/models.dart';
import '../../data/discovery_providers.dart';
import '../../data/user_data_providers.dart';
import '../../downloads/offline_mode.dart';
import '../../player/persistence.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/album_card.dart';
import '../widgets/busy_banner.dart';
import '../widgets/carousel.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_item_card.dart';
import '../widgets/mosaic_cover.dart';
import '../widgets/pill_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/section_header.dart';
import '../widgets/shelf_section.dart';
import '../widgets/skeleton.dart';

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
    final isOffline = ref.watch(isOfflineModeProvider);
    final homeFeedAsync = ref.watch(homeFeedProvider);
    final chartsAsync = ref.watch(chartsProvider(null));
    final recentAsync = ref.watch(recentProvider);
    final playlistsAsync = ref.watch(playlistsProvider);

    final settingsButton = GestureDetector(
      onTap: () => context.push('/settings'),
      child: Tooltip(
        message: 'Settings & Profile',
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tokens.surface2,
            shape: BoxShape.circle,
            border: Border.all(
              color: tokens.separator,
              width: 1,
            ),
          ),
          child: Icon(
            Icons.person_rounded,
            color: tokens.accent,
            size: 22,
          ),
        ),
      ),
    );

    if (isOffline) {
      return ScreenScaffold(
        title: 'Listen Now',
        trailing: settingsButton,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "You're offline",
              subtitle: 'Only downloaded music is playable in offline mode.',
              action: PillButton(
                label: 'Go to Downloads',
                icon: Icons.download_done_rounded,
                onTap: () => context.push('/downloaded'),
              ),
            ),
          ),
        ],
      );
    }

    return ScreenScaffold(
      title: 'Listen Now',
      trailing: settingsButton,
      slivers: [
        // 1. Home Feed / Shelves
        homeFeedAsync.when(
          data: (shelves) {
            if (shelves.isEmpty) {
              // Fallback to charts preview if home feed returned no shelves
              return chartsAsync.maybeWhen(
                data: (chartShelves) {
                  if (chartShelves.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  final topShelf = chartShelves.first;
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                        child: SectionHeader(
                          title: 'Top Hits',
                          subtitle: topShelf.subtitle ?? 'Trending music for you',
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingMd),
                      AlbumCarousel(
                        children: topShelf.items.map((item) {
                          return MediaItemCard(item: item, width: 170);
                        }).toList(),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingXl),
                    ]),
                  );
                },
                orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              );
            }

            final widgets = <Widget>[];

            // A. Top Picks hero section (first shelf with large cards)
            final topShelf = shelves.first;
            widgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                child: SectionHeader(
                  title: 'Top Picks',
                  subtitle: topShelf.subtitle ?? 'Hand-picked music for today',
                ),
              ),
            );
            widgets.add(const SizedBox(height: MelodiaTokens.spacingMd));
            widgets.add(
              AlbumCarousel(
                children: topShelf.items.map((item) {
                  return MediaItemCard(
                    item: item,
                    width: 200,
                  );
                }).toList(),
              ),
            );
            widgets.add(const SizedBox(height: MelodiaTokens.spacingXl));

            // B. Remaining discovery shelves
            for (int i = 1; i < shelves.length; i++) {
              widgets.add(ShelfSection(shelf: shelves[i]));
            }

            return SliverList(delegate: SliverChildListDelegate(widgets));
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MelodiaTokens.spacingLg,
                vertical: MelodiaTokens.spacingMd,
              ),
              child: SkeletonCardList(count: 3),
            ),
          ),
          error: (err, _) {
            if (err is UpstreamBusyError) {
              return SliverToBoxAdapter(
                child: BusyBanner(
                  retryAfterSeconds: err.retryAfterSeconds,
                  onRetry: () => ref.invalidate(homeFeedProvider),
                ),
              );
            }
            if (err is RateLimitError) {
              return SliverToBoxAdapter(
                child: BusyBanner(
                  retryAfterSeconds: err.retryAfterSeconds,
                  onRetry: () => ref.invalidate(homeFeedProvider),
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),

        // 2. Charts Preview Section
        chartsAsync.maybeWhen(
          data: (chartShelves) {
            if (chartShelves.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            final topCharts = chartShelves.first;
            return SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionHeader(
                        title: 'Trending Charts',
                        subtitle: 'Top hits and trending music',
                      ),
                      GestureDetector(
                        onTap: () => context.go('/browse'),
                        child: Text(
                          'See All',
                          style: MelodiaTokens.subhead.copyWith(
                            color: tokens.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                AlbumCarousel(
                  children: topCharts.items.take(8).map((item) {
                    return MediaItemCard(item: item, width: 150);
                  }).toList(),
                ),
                const SizedBox(height: MelodiaTokens.spacingXl),
              ]),
            );
          },
          orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // 3. Recently Played section
        recentAsync.when(
          data: (recentTracks) {
            if (recentTracks.isNotEmpty) {
              return SliverList(
                delegate: SliverChildListDelegate([
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                    child: SectionHeader(
                      title: 'Recently Played',
                      subtitle: 'Jump back into your recent listening',
                    ),
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

            final fallbackAsync = ref.watch(recentlyPlayedFallbackProvider);
            return fallbackAsync.maybeWhen(
              data: (localTracks) {
                if (localTracks.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverList(
                  delegate: SliverChildListDelegate([
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                      child: SectionHeader(
                        title: 'Recently Played',
                        subtitle: 'Jump back into your recent listening',
                      ),
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
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // 4. Playlists & Liked Songs section
        playlistsAsync.when(
          data: (playlists) {
            return SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: SectionHeader(
                    title: 'Your Playlists',
                    subtitle: 'Playlists you created and liked tracks',
                  ),
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
                const SizedBox(height: MelodiaTokens.spacingPage),
              ]),
            );
          },
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildLikedSongsCard(BuildContext context, MelodiaTokens tokens) {
    return Semantics(
      button: true,
      label: 'Liked Songs playlist',
      child: GestureDetector(
        onTap: () => context.push('/library'),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                  boxShadow: MelodiaTokens.cardShadow,
                ),
                child: Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 64,
                    color: tokens.accent,
                  ),
                ),
              ),
              const SizedBox(height: MelodiaTokens.spacingSm),
              Text(
                'Liked Songs',
                style: MelodiaTokens.subhead.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: MelodiaTokens.spacingXs),
              Text(
                'Auto playlist',
                style: MelodiaTokens.footnote.copyWith(
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context,
    Playlist playlist,
    MelodiaTokens tokens,
  ) {
    return Semantics(
      button: true,
      label: '${playlist.name}, ${playlist.trackCount} tracks',
      child: GestureDetector(
        onTap: () => context.push('/playlist/${playlist.id}'),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MosaicCover(
                coverThumbnails: playlist.coverThumbnails,
                size: 160,
              ),
              const SizedBox(height: MelodiaTokens.spacingSm),
              Text(
                playlist.name,
                style: MelodiaTokens.subhead.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: MelodiaTokens.spacingXs),
              Text(
                '${playlist.trackCount} tracks',
                style: MelodiaTokens.footnote.copyWith(
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
