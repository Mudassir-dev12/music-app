import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../downloads/download_models.dart';
import '../../downloads/download_repository.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/track_more_menu.dart';

enum DownloadSort { recentlyAdded, title, artist }

class DownloadedScreen extends ConsumerStatefulWidget {
  const DownloadedScreen({super.key});

  @override
  ConsumerState<DownloadedScreen> createState() => _DownloadedScreenState();
}

class _DownloadedScreenState extends ConsumerState<DownloadedScreen> {
  final TextEditingController _searchController = TextEditingController();
  DownloadSort _sort = DownloadSort.recentlyAdded;
  bool _isSelectionMode = false;
  final Set<String> _selectedVideoIds = {};

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1000) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  List<ManifestTrack> _filterAndSort(List<ManifestTrack> tracks) {
    final query = _searchController.text.trim().toLowerCase();
    var list = tracks;
    if (query.isNotEmpty) {
      list = list.where((t) {
        return t.title.toLowerCase().contains(query) ||
            t.artist.toLowerCase().contains(query) ||
            (t.album != null && t.album!.toLowerCase().contains(query));
      }).toList();
    }

    switch (_sort) {
      case DownloadSort.recentlyAdded:
        list.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
        break;
      case DownloadSort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case DownloadSort.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final downloadedTracks = ref.watch(downloadedTracksProvider);
    final queueItems = ref.watch(downloadQueueProvider).valueOrNull ?? [];
    final activeQueueCount = queueItems.where((i) =>
        i.status == DownloadStatus.downloading || i.status == DownloadStatus.queued).length;

    final filtered = _filterAndSort(downloadedTracks);
    final totalBytes = downloadedTracks.fold<int>(0, (sum, t) => sum + t.byteSize);

    return ScreenScaffold(
      title: 'Downloaded',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (downloadedTracks.isNotEmpty)
            IconButton(
              tooltip: _isSelectionMode ? 'Cancel' : 'Select',
              icon: Icon(
                _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                color: tokens.accent,
              ),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) {
                    _selectedVideoIds.clear();
                  }
                });
              },
            ),
          PopupMenuButton<DownloadSort>(
            icon: Icon(Icons.sort_rounded, color: tokens.text),
            tooltip: 'Sort by',
            color: tokens.surface2,
            onSelected: (sort) {
              setState(() {
                _sort = sort;
              });
            },
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem(
                value: DownloadSort.recentlyAdded,
                checked: _sort == DownloadSort.recentlyAdded,
                child: Text(
                  'Recently Added',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
              ),
              CheckedPopupMenuItem(
                value: DownloadSort.title,
                checked: _sort == DownloadSort.title,
                child: Text(
                  'Title',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
              ),
              CheckedPopupMenuItem(
                value: DownloadSort.artist,
                checked: _sort == DownloadSort.artist,
                child: Text(
                  'Artist',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
              ),
            ],
          ),
        ],
      ),
      slivers: [
        if (kIsWeb)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
              child: Container(
                padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: tokens.textSecondary, size: 20),
                    const SizedBox(width: MelodiaTokens.spacingSm),
                    Expanded(
                      child: Text(
                        'Downloads are available in the mobile app.',
                        style: MelodiaTokens.subhead.copyWith(color: tokens.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Stats bar & Queue navigation
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MelodiaTokens.spacingLg,
                MelodiaTokens.spacingSm,
                MelodiaTokens.spacingLg,
                MelodiaTokens.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${downloadedTracks.length} songs • ${_formatSize(totalBytes)}',
                      style: MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: Icon(
                      Icons.downloading_rounded,
                      size: 18,
                      color: activeQueueCount > 0 ? tokens.accent : tokens.textSecondary,
                    ),
                    label: Text(
                      activeQueueCount > 0 ? 'Queue ($activeQueueCount)' : 'Queue',
                      style: MelodiaTokens.subhead.copyWith(
                        color: activeQueueCount > 0 ? tokens.accent : tokens.textSecondary,
                        fontWeight: activeQueueCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onPressed: () => context.push('/downloads/queue'),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          if (downloadedTracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MelodiaTokens.spacingLg,
                  vertical: MelodiaTokens.spacingSm,
                ),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: tokens.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: MelodiaTokens.body.copyWith(color: tokens.text),
                          decoration: InputDecoration(
                            hintText: 'Search downloads',
                            hintStyle: MelodiaTokens.body.copyWith(color: tokens.textTertiary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: Icon(Icons.cancel_rounded, size: 16, color: tokens.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Selection actions toolbar
          if (_isSelectionMode && _selectedVideoIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MelodiaTokens.spacingLg,
                  vertical: MelodiaTokens.spacingXs,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    borderRadius: BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedVideoIds.length} selected',
                        style: MelodiaTokens.subhead.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: tokens.destructive),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        onPressed: () async {
                          final count = _selectedVideoIds.length;
                          final manager = ref.read(downloadManagerProvider);
                          for (final vid in _selectedVideoIds) {
                            await manager.removeDownloadedTrack(vid);
                          }
                          setState(() {
                            _selectedVideoIds.clear();
                            _isSelectionMode = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Removed $count downloads.',
                                  style: MelodiaTokens.footnote.copyWith(color: tokens.text),
                                ),
                                backgroundColor: tokens.surface2,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Downloaded list
          if (downloadedTracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.arrow_circle_down_rounded,
                title: 'No downloaded music',
                subtitle: 'Songs and albums you download will appear here for offline listening.',
                action: PillButton(
                  icon: Icons.explore_rounded,
                  label: 'Explore Music',
                  onTap: () => context.go('/browse'),
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results found',
                subtitle: 'No downloads matched "${_searchController.text.trim()}".',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = filtered[index];
                  final track = item.toTrack();
                  final isSelected = _selectedVideoIds.contains(item.videoId);

                  final rowWidget = Dismissible(
                    key: Key('dl_${item.videoId}'),
                    direction: _isSelectionMode
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    background: Container(
                      color: tokens.destructive,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: MelodiaTokens.spacingLg),
                      child: Icon(Icons.delete_outline_rounded, color: tokens.text),
                    ),
                    onDismissed: (_) {
                      ref.read(downloadManagerProvider).removeDownloadedTrack(item.videoId);
                      HapticFeedback.lightImpact();
                    },
                    child: Material(
                      color: tokens.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedVideoIds.remove(item.videoId);
                              } else {
                                _selectedVideoIds.add(item.videoId);
                              }
                            });
                          } else {
                            final allTracks = filtered.map((e) => e.toTrack()).toList();
                            ref.read(playerControllerProvider.notifier).playList(allTracks, index);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MelodiaTokens.spacingLg,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              if (_isSelectionMode) ...[
                                Checkbox(
                                  value: isSelected,
                                  activeColor: tokens.accent,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedVideoIds.add(item.videoId);
                                      } else {
                                        _selectedVideoIds.remove(item.videoId);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: MelodiaTokens.spacingXs),
                              ],
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
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_circle_down_rounded,
                                          size: 13,
                                          color: tokens.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${item.artist} • ${_formatSize(item.byteSize)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: MelodiaTokens.footnote.copyWith(
                                              color: tokens.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isSelectionMode)
                                IconButton(
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    color: tokens.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => showTrackMoreMenu(
                                    context: context,
                                    ref: ref,
                                    track: track,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  return Column(
                    children: [
                      rowWidget,
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
                childCount: filtered.length,
              ),
            ),
        ],
      ],
    );
  }
}
