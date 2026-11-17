import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloads/download_models.dart';
import '../../downloads/download_repository.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_scaffold.dart';

class DownloadQueueScreen extends ConsumerWidget {
  const DownloadQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final manager = ref.watch(downloadManagerProvider);
    final queueItems = ref.watch(downloadQueueProvider).valueOrNull ?? manager.queue;

    final hasActive = queueItems.any((i) =>
        i.status == DownloadStatus.downloading || i.status == DownloadStatus.queued);
    final hasPaused = queueItems.any((i) =>
        i.status == DownloadStatus.paused || i.status == DownloadStatus.failed);

    Widget? trailingWidget;
    if (queueItems.isNotEmpty) {
      if (hasActive) {
        trailingWidget = TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: tokens.accent),
          icon: const Icon(Icons.pause_rounded, size: 18),
          label: const Text('Pause all'),
          onPressed: () => manager.pauseAll(),
        );
      } else if (hasPaused) {
        trailingWidget = TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: tokens.accent),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Resume all'),
          onPressed: () => manager.resumeAll(),
        );
      }
    }

    return ScreenScaffold(
      title: 'Download Queue',
      trailing: trailingWidget,
      slivers: [
        if (queueItems.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.done_all_rounded,
              title: 'Queue is empty',
              subtitle: 'All downloads have completed.',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = queueItems[index];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MelodiaTokens.spacingLg,
                        vertical: MelodiaTokens.spacingSm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MelodiaTokens.body.copyWith(
                                    color: tokens.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.artist} • ${item.statusText}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MelodiaTokens.footnote.copyWith(
                                    color: item.status == DownloadStatus.failed
                                        ? tokens.destructive
                                        : tokens.textSecondary,
                                  ),
                                ),
                                if (item.status == DownloadStatus.downloading) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: item.progress > 0 ? item.progress : null,
                                      backgroundColor: tokens.surface2,
                                      valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: MelodiaTokens.spacingSm),
                          // Actions per item
                          if (item.status == DownloadStatus.downloading)
                            IconButton(
                              icon: Icon(Icons.pause_circle_outline_rounded,
                                  color: tokens.textSecondary, size: 22),
                              tooltip: 'Pause',
                              onPressed: () => manager.pause(item.videoId),
                            )
                          else if (item.status == DownloadStatus.paused ||
                              item.status == DownloadStatus.failed)
                            IconButton(
                              icon: Icon(Icons.play_circle_outline_rounded,
                                  color: tokens.accent, size: 22),
                              tooltip: 'Resume',
                              onPressed: () => manager.resume(item.videoId),
                            ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                color: tokens.textSecondary, size: 20),
                            tooltip: 'Options',
                            color: tokens.surface2,
                            onSelected: (val) {
                              if (val == 'next') {
                                manager.downloadNext(item.videoId);
                              } else if (val == 'cancel') {
                                manager.cancel(item.videoId);
                              } else if (val == 'retry') {
                                manager.resume(item.videoId);
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (index > 0 && item.status == DownloadStatus.queued)
                                PopupMenuItem(
                                  value: 'next',
                                  child: Text('Download next',
                                      style: MelodiaTokens.body.copyWith(color: tokens.text)),
                                ),
                              if (item.status == DownloadStatus.failed)
                                PopupMenuItem(
                                  value: 'retry',
                                  child: Text('Retry',
                                      style: MelodiaTokens.body.copyWith(color: tokens.text)),
                                ),
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancel',
                                    style: MelodiaTokens.body
                                        .copyWith(color: tokens.destructive)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: MelodiaTokens.spacingLg),
                      child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: tokens.separator,
                      ),
                    ),
                  ],
                );
              },
              childCount: queueItems.length,
            ),
          ),
      ],
    );
  }
}
