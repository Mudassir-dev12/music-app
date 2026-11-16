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
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/track_row.dart';

class YtPlaylistScreen extends ConsumerWidget {
  const YtPlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  String _formatTotalDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    } else {
      return '$minutes min';
    }
  }

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
    final playlistAsync = ref.watch(ytPlaylistDetailProvider(playlistId));

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
      body: playlistAsync.when(
        data: (pl) {
          final durStr = _formatTotalDuration(pl.durationSeconds);
          final meta = [
            if (pl.author != null && pl.author!.isNotEmpty) pl.author!,
            '${pl.trackCount} ${pl.trackCount == 1 ? "song" : "songs"}',
            if (durStr.isNotEmpty) durStr,
          ].join(' • ');

          return CustomScrollView(
            slivers: [
              // 1. Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                          boxShadow: MelodiaTokens.cardShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                          child: pl.thumbnail != null && pl.thumbnail!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: pl.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.queue_music_rounded,
                                    size: 64,
                                    color: tokens.textTertiary,
                                  ),
                                )
                              : Icon(
                                  Icons.queue_music_rounded,
                                  size: 64,
                                  color: tokens.textTertiary,
                                ),
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),
                      Text(
                        pl.title,
                        textAlign: TextAlign.center,
                        style: MelodiaTokens.title2.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingSm),
                      Text(
                        meta,
                        textAlign: TextAlign.center,
                        style: MelodiaTokens.footnote.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),

                      // Play & Shuffle Pills
                      if (pl.tracks.isNotEmpty)
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
                                onPressed: () => _playAll(ref, pl.tracks, shuffle: false),
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
                                onPressed: () => _playAll(ref, pl.tracks, shuffle: true),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: MelodiaTokens.spacingXl),
                    ],
                  ),
                ),
              ),

              // 2. Tracks List
              if (pl.tracks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.music_off_rounded,
                    title: 'No Tracks',
                    subtitle: 'This playlist currently has no playable tracks.',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = pl.tracks[index];
                      return TrackRow(
                        track: track,
                        onTap: () {
                          ref.read(playerControllerProvider.notifier).playQueue(
                                pl.tracks,
                                initialIndex: index,
                              );
                        },
                      );
                    },
                    childCount: pl.tracks.length,
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
                onRetry: () => ref.invalidate(ytPlaylistDetailProvider(playlistId)),
              ),
            );
          }
          return Center(
            child: ErrorState(
              message: 'Failed to load playlist.',
              onRetry: () => ref.invalidate(ytPlaylistDetailProvider(playlistId)),
            ),
          );
        },
      ),
    );
  }
}
