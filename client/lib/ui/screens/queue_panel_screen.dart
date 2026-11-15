import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../player/player_controller.dart';
import '../../player/queue.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/track_row.dart';

class QueuePanelScreen extends ConsumerWidget {
  const QueuePanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final queue = playerState.queue;

    final currentTrack = queue.currentTrack;
    final playNextList = queue.playNextQueue;
    final List<Track> upNextList = queue.currentIndex >= 0 && queue.currentIndex < queue.queue.length - 1
        ? queue.queue.sublist(queue.currentIndex + 1)
        : <Track>[];

    final isShuffle = queue.shuffle;
    final repeatMode = queue.repeat;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: tokens.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Playing Next',
          style: MelodiaTokens.headline.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: isShuffle ? tokens.accent : tokens.textSecondary,
              size: 22,
            ),
            tooltip: 'Shuffle',
            onPressed: () => controller.toggleShuffle(),
          ),
          IconButton(
            icon: Icon(
              repeatMode == RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: repeatMode != RepeatMode.off ? tokens.accent : tokens.textSecondary,
              size: 22,
            ),
            tooltip: 'Repeat',
            onPressed: () => controller.cycleRepeat(),
          ),
          const SizedBox(width: MelodiaTokens.spacingSm),
        ],
      ),
      body: queue.isEmpty
          ? const EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'Queue is Empty',
              subtitle: 'Play songs from Search or Listen Now to start your queue.',
            )
          : ListView(
              children: [
                // 1. Now Playing Section
                if (currentTrack != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingLg,
                      vertical: MelodiaTokens.spacingSm,
                    ),
                    child: Text(
                      'NOW PLAYING',
                      style: MelodiaTokens.caption.copyWith(
                        color: tokens.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  TrackRow(
                    track: currentTrack,
                    isCurrentTrack: true,
                    isPlaying: playerState.isPlaying,
                  ),
                  const SizedBox(height: MelodiaTokens.spacingLg),
                ],

                // 2. Playing Next Section (user queued)
                if (playNextList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingLg,
                      vertical: MelodiaTokens.spacingSm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PLAYING NEXT',
                          style: MelodiaTokens.caption.copyWith(
                            color: tokens.textTertiary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => controller.clearPlayNext(),
                          child: Text(
                            'Clear',
                            style: MelodiaTokens.caption.copyWith(
                              color: tokens.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(playNextList.length, (idx) {
                    final track = playNextList[idx];
                    return Dismissible(
                      key: ValueKey('playnext_${track.videoId}_$idx'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: tokens.destructive,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: MelodiaTokens.spacingLg),
                        child: Icon(Icons.delete_rounded, color: tokens.text),
                      ),
                      onDismissed: (_) {
                        // Remove from playNext
                      },
                      child: TrackRow(
                        track: track,
                        onTap: () => controller.playTrack(track),
                      ),
                    );
                  }),
                  const SizedBox(height: MelodiaTokens.spacingLg),
                ],

                // 3. Up Next Section (remaining queue with reordering)
                if (upNextList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingLg,
                      vertical: MelodiaTokens.spacingSm,
                    ),
                    child: Text(
                      'UP NEXT',
                      style: MelodiaTokens.caption.copyWith(
                        color: tokens.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: upNextList.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      final actualOld = queue.currentIndex + 1 + oldIndex;
                      final actualNew = queue.currentIndex + 1 + (newIndex > oldIndex ? newIndex - 1 : newIndex);
                      controller.move(actualOld, actualNew);
                    },
                    itemBuilder: (context, index) {
                      final track = upNextList[index];
                      final actualIndex = queue.currentIndex + 1 + index;

                      return Dismissible(
                        key: ValueKey('queue_${track.videoId}_$actualIndex'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: tokens.destructive,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: MelodiaTokens.spacingLg),
                          child: Icon(Icons.delete_rounded, color: tokens.text),
                        ),
                        onDismissed: (_) {
                          controller.removeAt(actualIndex);
                        },
                        child: TrackRow(
                          key: ValueKey('row_${track.videoId}_$actualIndex'),
                          track: track,
                          onTap: () {
                            controller.playList(queue.queue, actualIndex);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
