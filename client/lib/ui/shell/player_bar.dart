import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../player/player_controller.dart';
import '../../player/player_state.dart';
import '../../player/queue.dart';
import '../../theme/tokens.dart';
import '../widgets/like_button.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/volume_slider.dart';

class DesktopPlayerBar extends ConsumerWidget {
  const DesktopPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final currentTrack = playerState.queue.currentTrack;

    if (currentTrack == null) {
      return Container(
        height: 76,
        decoration: BoxDecoration(
          color: tokens.surface2,
          border: Border(
            top: BorderSide(
              color: tokens.separator,
              width: 0.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'Select a song to play',
          style: MelodiaTokens.subhead.copyWith(color: tokens.textTertiary),
        ),
      );
    }

    final isPlaying = playerState.status == PlayerStatus.playing;
    final isShuffle = playerState.queue.shuffle;
    final repeatMode = playerState.queue.repeat;

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border(
          top: BorderSide(
            color: tokens.separator,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
      child: Row(
        children: [
          // Left: Artwork + Title + Artist
          GestureDetector(
            onTap: () => context.push('/now-playing'),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: currentTrack.thumbnail != null &&
                            currentTrack.thumbnail!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentTrack.thumbnail!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: tokens.surface),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.music_note_rounded,
                              color: tokens.textTertiary,
                            ),
                          )
                        : Icon(
                            Icons.music_note_rounded,
                            color: tokens.textTertiary,
                          ),
                  ),
                ),
                const SizedBox(width: MelodiaTokens.spacingMd),
                SizedBox(
                  width: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MelodiaTokens.subhead.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        currentTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MelodiaTokens.caption.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MelodiaTokens.spacingSm),
          LikeHeartButton(track: currentTrack, size: 20),

          // Center: Controls + Scrubber
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle ? tokens.accent : tokens.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => controller.toggleShuffle(),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: tokens.text,
                        size: 24,
                      ),
                      onPressed: () => controller.skipPrevious(),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tokens.text,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: tokens.background,
                          size: 24,
                        ),
                        onPressed: () => controller.togglePlayPause(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: tokens.text,
                        size: 24,
                      ),
                      onPressed: () => controller.skipNext(),
                    ),
                    IconButton(
                      icon: Icon(
                        repeatMode == RepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: repeatMode != RepeatMode.off
                            ? tokens.accent
                            : tokens.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => controller.cycleRepeat(),
                    ),
                  ],
                ),
                SizedBox(
                  width: 500,
                  height: 24,
                  child: ScrubBar(
                    position: playerState.position,
                    duration: playerState.duration,
                    onSeek: (pos) => controller.seekTo(pos),
                  ),
                ),
              ],
            ),
          ),

          // Right: Volume + Queue button
          Row(
            children: [
              VolumeSlider(
                volume: playerState.volume,
                onChanged: (v) => controller.setVolume(v),
              ),
              const SizedBox(width: MelodiaTokens.spacingMd),
              IconButton(
                icon: Icon(
                  Icons.queue_music_rounded,
                  color: tokens.textSecondary,
                  size: 22,
                ),
                tooltip: 'Queue',
                onPressed: () => context.push('/queue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
