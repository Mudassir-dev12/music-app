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
import '../widgets/collection_download_button.dart';
import '../widgets/error_state.dart';
import '../widgets/track_more_menu.dart';

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.albumId});

  final String albumId;

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

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
    final albumAsync = ref.watch(albumDetailProvider(albumId));

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
      body: albumAsync.when(
        data: (album) {
          final durationStr = _formatTotalDuration(album.durationSeconds);
          final metaLine = [
            if (album.year != null) '${album.year}',
            '${album.trackCount} ${album.trackCount == 1 ? "song" : "songs"}',
            if (durationStr.isNotEmpty) durationStr,
          ].join(' • ');

          return CustomScrollView(
            slivers: [
              // 1. Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: Column(
                    children: [
                      // Artwork
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
                          child: album.thumbnail != null && album.thumbnail!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: album.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.album_rounded,
                                    size: 64,
                                    color: tokens.textTertiary,
                                  ),
                                )
                              : Icon(
                                  Icons.album_rounded,
                                  size: 64,
                                  color: tokens.textTertiary,
                                ),
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),

                      // Title
                      Text(
                        album.title,
                        textAlign: TextAlign.center,
                        style: MelodiaTokens.title2.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingSm),

                      // Artist Link
                      GestureDetector(
                        onTap: () {
                          final artistId = album.artists.isNotEmpty ? album.artists.first.id : null;
                          if (artistId != null && artistId.isNotEmpty) {
                            context.push('/artist/$artistId');
                          }
                        },
                        child: Text(
                          album.artist,
                          textAlign: TextAlign.center,
                          style: MelodiaTokens.headline.copyWith(
                            color: tokens.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingSm),

                      // Metadata line
                      Text(
                        metaLine,
                        style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),

                      // Play & Shuffle Pills
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
                              onPressed: () => _playAll(ref, album.tracks, shuffle: false),
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
                              onPressed: () => _playAll(ref, album.tracks, shuffle: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: MelodiaTokens.spacingMd),
                      CollectionDownloadButton(
                        collectionKey: 'album:${album.id}',
                        title: album.title,
                        tracks: album.tracks,
                      ),
                      const SizedBox(height: MelodiaTokens.spacingXl),
                    ],
                  ),
                ),
              ),

              // 2. Tracks List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = album.tracks[index];
                    final trackNumber = track.trackNumber ?? (index + 1);
                    final durStr = _formatDuration(track.durationSeconds);

                    return InkWell(
                      onTap: () {
                        ref.read(playerControllerProvider.notifier).playQueue(
                              album.tracks,
                              initialIndex: index,
                            );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MelodiaTokens.spacingLg,
                          vertical: MelodiaTokens.spacingMd,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$trackNumber',
                                style: MelodiaTokens.subhead.copyWith(
                                  color: tokens.textTertiary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          track.title,
                                          style: MelodiaTokens.body.copyWith(
                                            color: tokens.text,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (track.isExplicit) ...[
                                        const SizedBox(width: MelodiaTokens.spacingXs),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: MelodiaTokens.spacingXs,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.surface2,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            'E',
                                            style: MelodiaTokens.caption.copyWith(
                                              color: tokens.textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (track.artist != album.artist) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artist,
                                      style: MelodiaTokens.footnote.copyWith(
                                        color: tokens.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (durStr.isNotEmpty) ...[
                              const SizedBox(width: MelodiaTokens.spacingSm),
                              Text(
                                durStr,
                                style: MelodiaTokens.footnote.copyWith(
                                  color: tokens.textTertiary,
                                ),
                              ),
                            ],
                            IconButton(
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: tokens.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                showTrackMoreMenu(
                                  context: context,
                                  ref: ref,
                                  track: track,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: album.tracks.length,
                ),
              ),

              // 3. Metadata Footer
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: tokens.separator, thickness: 0.5),
                      const SizedBox(height: MelodiaTokens.spacingMd),
                      if (album.description != null && album.description!.isNotEmpty) ...[
                        Text(
                          album.description!,
                          style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                        ),
                        const SizedBox(height: MelodiaTokens.spacingMd),
                      ],
                      if (album.year != null)
                        Text(
                          'Released ${album.year}',
                          style: MelodiaTokens.caption.copyWith(color: tokens.textTertiary),
                        ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          if (err is UpstreamBusyError) {
            return Center(
              child: BusyBanner(
                retryAfterSeconds: err.retryAfterSeconds,
                onRetry: () => ref.invalidate(albumDetailProvider(albumId)),
              ),
            );
          }
          return Center(
            child: ErrorState(
              message: 'Failed to load album.',
              onRetry: () => ref.invalidate(albumDetailProvider(albumId)),
            ),
          );
        },
      ),
    );
  }
}
