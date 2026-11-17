import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/track_row.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(historyProvider.notifier).loadMore();
    }
  }

  String _formatDayHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(itemDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _showClearHistoryDialog() async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Clear Listening History?',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Text(
          'This will clear your listening history across all devices.',
          style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.destructive,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Clear History',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(historyProvider.notifier).clearHistory();
    }
  }

  void _showHistoryMoreMenu(
      BuildContext context, HistoryItem item, MelodiaTokens tokens) {
    final trk = item.track;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MelodiaTokens.radiusSheet),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MelodiaTokens.spacingMd,
            horizontal: MelodiaTokens.spacingLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.play_arrow_rounded, color: tokens.text),
                title: Text(
                  'Play',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ref.read(playerControllerProvider.notifier).playTrack(trk);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.playlist_add_rounded, color: tokens.text),
                title: Text(
                  'Add to a Playlist...',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showAddToPlaylistSheet(this.context, trk);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: tokens.destructive),
                title: Text(
                  'Remove from History',
                  style:
                      MelodiaTokens.body.copyWith(color: tokens.destructive),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ref.read(historyProvider.notifier).deleteItem(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final historyAsync = ref.watch(historyProvider);
    final playerState = ref.watch(playerControllerProvider);
    final currentVid = playerState.queue.currentTrack?.videoId;
    final isPlaying = playerState.isPlaying;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        surfaceTintColor: tokens.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.accent,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
        ),
        title: Text(
          'History',
          style: MelodiaTokens.title2.copyWith(color: tokens.text),
        ),
        actions: [
          TextButton(
            onPressed: historyAsync.valueOrNull?.items.isNotEmpty == true
                ? _showClearHistoryDialog
                : null,
            child: Text(
              'Clear',
              style: MelodiaTokens.subhead.copyWith(
                color: historyAsync.valueOrNull?.items.isNotEmpty == true
                    ? tokens.accent
                    : tokens.textTertiary,
              ),
            ),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
          ),
        ),
        error: (err, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load history',
            subtitle: err.toString(),
          ),
        ),
        data: (page) {
          final items = page.items;
          if (items.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No Listening History',
                subtitle: 'Tracks you listen to will appear here.',
              ),
            );
          }

          // Group items by day
          final Map<String, List<HistoryItem>> grouped = {};
          for (final it in items) {
            final key = _formatDayHeader(it.playedAt);
            grouped.putIfAbsent(key, () => []).add(it);
          }

          final keys = grouped.keys.toList();

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              bottom: 120, // Mini player inset
            ),
            itemCount: keys.length + (page.hasMore ? 1 : 0),
            itemBuilder: (context, sectionIndex) {
              if (sectionIndex == keys.length) {
                return Padding(
                  padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(tokens.accent),
                    ),
                  ),
                );
              }

              final groupKey = keys[sectionIndex];
              final groupItems = grouped[groupKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MelodiaTokens.spacingLg,
                      MelodiaTokens.spacingLg,
                      MelodiaTokens.spacingLg,
                      MelodiaTokens.spacingSm,
                    ),
                    child: Text(
                      groupKey,
                      style: MelodiaTokens.footnote.copyWith(
                        color: tokens.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...groupItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final it = entry.value;
                    final trk = it.track;
                    final isCurrent = trk.videoId == currentVid;

                    return TrackRow(
                      track: trk,
                      index: idx,
                      isCurrentTrack: isCurrent,
                      isPlaying: isPlaying,
                      onTap: () {
                        final tracks = items.map((e) => e.track).toList();
                        final itemIndex = items.indexOf(it);
                        ref
                            .read(playerControllerProvider.notifier)
                            .playList(tracks, itemIndex >= 0 ? itemIndex : 0);
                      },
                      trailing: IconButton(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () =>
                            _showHistoryMoreMenu(context, it, tokens),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
