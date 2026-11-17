import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../data/discovery_providers.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/busy_banner.dart';
import '../widgets/carousel.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/media_item_card.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';

class MoodPlaylistsScreen extends ConsumerWidget {
  const MoodPlaylistsScreen({
    super.key,
    required this.params,
    required this.title,
  });

  final String params;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(moodPlaylistsProvider(params));
    final songsAsync = ref.watch(searchFilterProvider((query: title, filter: 'songs')));

    return ScreenScaffold(
      title: title,
      slivers: [
        // 1. Related Songs Section
        songsAsync.maybeWhen(
          data: (searchFilter) {
            final songs = searchFilter.results;
            if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

            return SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: SectionHeader(
                    title: 'Top $title Songs',
                    subtitle: 'Popular tracks matching this mood',
                  ),
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                AlbumCarousel(
                  children: songs.take(10).map((item) {
                    return MediaItemCard(
                      item: item,
                      width: 150,
                      onTap: () {
                        ref.read(playerControllerProvider.notifier).playTrack(item.toTrack());
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: MelodiaTokens.spacingXl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: SectionHeader(
                    title: '$title Playlists',
                    subtitle: 'Curated playlists and albums',
                  ),
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
              ]),
            );
          },
          orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // 2. Playlists Grid
        playlistsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.queue_music_rounded,
                  title: 'No Playlists Found',
                  subtitle: 'No playlists available for this category right now.',
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: MelodiaTokens.spacingLg,
                vertical: MelodiaTokens.spacingMd,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: MelodiaTokens.spacingLg,
                  crossAxisSpacing: MelodiaTokens.spacingLg,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return MediaItemCard(item: item, width: 170);
                  },
                  childCount: items.length,
                ),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: SkeletonTrackList(count: 6),
          ),
          error: (err, _) {
            if (err is UpstreamBusyError) {
              return SliverToBoxAdapter(
                child: BusyBanner(
                  retryAfterSeconds: err.retryAfterSeconds,
                  onRetry: () => ref.invalidate(moodPlaylistsProvider(params)),
                ),
              );
            }
            return SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorState(
                message: 'Failed to load playlists.',
                onRetry: () => ref.invalidate(moodPlaylistsProvider(params)),
              ),
            );
          },
        ),
      ],
    );
  }
}
