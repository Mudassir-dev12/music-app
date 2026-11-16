import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/models.dart';
import '../../data/discovery_providers.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/busy_banner.dart';
import '../widgets/carousel.dart';
import '../widgets/error_state.dart';
import '../widgets/media_item_card.dart';
import '../widgets/section_header.dart';
import '../widgets/track_row.dart';

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artistId});

  final String artistId;

  void _playAll(WidgetRef ref, List<Track> tracks, {bool shuffle = false}) {
    if (tracks.isEmpty) return;
    ref.read(playerControllerProvider.notifier).playQueue(tracks, initialIndex: 0);
    if (shuffle) {
      ref.read(playerControllerProvider.notifier).toggleShuffle();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final artistAsync = ref.watch(artistDetailProvider(artistId));

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tokens.accent),
          onPressed: () => context.pop(),
        ),
      ),
      body: artistAsync.when(
        data: (artist) {
          return CustomScrollView(
            slivers: [
              // 1. Hero Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: Column(
                    children: [
                      // Circular Hero Image
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          shape: BoxShape.circle,
                          boxShadow: MelodiaTokens.cardShadow,
                        ),
                        child: ClipOval(
                          child: artist.thumbnail != null && artist.thumbnail!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: artist.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.person_rounded,
                                    size: 64,
                                    color: tokens.textTertiary,
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 64,
                                  color: tokens.textTertiary,
                                ),
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),

                      // Artist Name
                      Text(
                        artist.name,
                        textAlign: TextAlign.center,
                        style: MelodiaTokens.largeTitle.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (artist.subscribers != null && artist.subscribers!.isNotEmpty) ...[
                        const SizedBox(height: MelodiaTokens.spacingXs),
                        Text(
                          '${artist.subscribers} subscribers',
                          style: MelodiaTokens.footnote.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: MelodiaTokens.spacingLg),

                      // Play & Shuffle Top Songs
                      if (artist.topSongs.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: tokens.surface2,
                                  foregroundColor: tokens.accent,
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                                  ),
                                ),
                                icon: Icon(Icons.play_arrow_rounded, color: tokens.accent, size: 24),
                                label: Text(
                                  'Play',
                                  style: MelodiaTokens.headline.copyWith(color: tokens.accent),
                                ),
                                onPressed: () => _playAll(ref, artist.topSongs, shuffle: false),
                              ),
                            ),
                            const SizedBox(width: MelodiaTokens.spacingMd),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: tokens.surface2,
                                  foregroundColor: tokens.accent,
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                                  ),
                                ),
                                icon: Icon(Icons.shuffle_rounded, color: tokens.accent, size: 24),
                                label: Text(
                                  'Shuffle',
                                  style: MelodiaTokens.headline.copyWith(color: tokens.accent),
                                ),
                                onPressed: () => _playAll(ref, artist.topSongs, shuffle: true),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: MelodiaTokens.spacingXl),
                    ],
                  ),
                ),
              ),

              // 2. Top Songs
              if (artist.topSongs.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                    child: SectionHeader(
                      title: 'Top Songs',
                      subtitle: 'Most popular tracks',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = artist.topSongs[index];
                      return TrackRow(
                        track: track,
                        onTap: () {
                          ref.read(playerControllerProvider.notifier).playQueue(
                                artist.topSongs,
                                initialIndex: index,
                              );
                        },
                      );
                    },
                    childCount: artist.topSongs.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingXl)),
              ],

              // 3. Albums Carousel
              if (artist.albums.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                    child: SectionHeader(
                      title: 'Albums',
                      subtitle: 'Full discography',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingMd)),
                SliverToBoxAdapter(
                  child: AlbumCarousel(
                    children: artist.albums.map((alb) {
                      return MediaItemCard(item: alb, width: 160);
                    }).toList(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingXl)),
              ],

              // 4. Singles & EPs Carousel
              if (artist.singles.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                    child: SectionHeader(
                      title: 'Singles & EPs',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingMd)),
                SliverToBoxAdapter(
                  child: AlbumCarousel(
                    children: artist.singles.map((s) {
                      return MediaItemCard(item: s, width: 160);
                    }).toList(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingXl)),
              ],

              // 5. Related Artists Carousel ("Fans Also Like")
              if (artist.related.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                    child: SectionHeader(
                      title: 'Fans Also Like',
                      subtitle: 'Similar artists you might enjoy',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingMd)),
                SliverToBoxAdapter(
                  child: AlbumCarousel(
                    children: artist.related.map((rel) {
                      return MediaItemCard(item: rel, width: 140);
                    }).toList(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: MelodiaTokens.spacingXl)),
              ],

              // 6. About / Bio section
              if (artist.description != null && artist.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'About'),
                        const SizedBox(height: MelodiaTokens.spacingSm),
                        Text(
                          artist.description!,
                          style: MelodiaTokens.body.copyWith(
                            color: tokens.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          if (err is UpstreamBusyError) {
            return Center(
              child: BusyBanner(
                retryAfterSeconds: err.retryAfterSeconds,
                onRetry: () => ref.invalidate(artistDetailProvider(artistId)),
              ),
            );
          }
          return Center(
            child: ErrorState(
              message: 'Failed to load artist.',
              onRetry: () => ref.invalidate(artistDetailProvider(artistId)),
            ),
          );
        },
      ),
    );
  }
}
