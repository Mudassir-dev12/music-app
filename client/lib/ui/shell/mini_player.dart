import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../player/player_controller.dart';
import '../../player/player_state.dart';
import '../../theme/tokens.dart';
import '../widgets/marquee_text.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final currentTrack = playerState.queue.currentTrack;

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final controller = ref.read(playerControllerProvider.notifier);

    final totalMs = playerState.duration.inMilliseconds.toDouble();
    final posMs = playerState.position.inMilliseconds.toDouble();
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: 'Mini Player: ${currentTrack.title} by ${currentTrack.artist}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/now-playing'),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
            context.push('/now-playing');
          }
        },
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: tokens.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Thin progress line along the top edge
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: tokens.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MelodiaTokens.spacingLg,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              MelodiaTokens.radiusArtworkSm,
                            ),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: currentTrack.thumbnail != null &&
                                      currentTrack.thumbnail!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: currentTrack.thumbnail!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: tokens.surface2,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: tokens.surface2,
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          color: tokens.textTertiary,
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: tokens.surface2,
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        color: tokens.textTertiary,
                                        size: 24,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: MelodiaTokens.spacingMd),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarqueeText(
                                  text: currentTrack.title,
                                  style: MelodiaTokens.body.copyWith(
                                    color: tokens.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTrack.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MelodiaTokens.footnote.copyWith(
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 36x36 play/pause button
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                playerState.status == PlayerStatus.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: tokens.text,
                                size: 32,
                              ),
                              onPressed: () => controller.togglePlayPause(),
                            ),
                          ),
                          const SizedBox(width: MelodiaTokens.spacingSm),
                          // 36x36 next button
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.fast_forward_rounded,
                                color: tokens.text,
                                size: 28,
                              ),
                              onPressed: () => controller.skipNext(),
                            ),
                          ),
                        ],
                      ),
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
}
