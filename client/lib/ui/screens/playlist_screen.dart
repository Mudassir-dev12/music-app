import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/collection_download_button.dart';
import '../widgets/mosaic_cover.dart';
import '../widgets/track_row.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.playlistId,
  });

  final String playlistId;

  bool get isLikedSongs => playlistId == 'liked';

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();

  // Temporary list for pending undo swipe removals
  final Set<String> _pendingRemovals = {};
  final Map<String, Timer> _pendingTimers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.isLikedSongs) {
        ref.read(likedSongsProvider.notifier).loadMore();
      } else {
        ref.read(playlistDetailProvider(widget.playlistId).notifier).loadMore();
      }
    }
  }

  String _formatTotalDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return ' • $hours hr $minutes min';
    } else {
      return ' • $minutes min';
    }
  }

  Future<void> _sharePlaylist(String title, List<Track> tracks) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final lines = <String>[
      title,
      '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
      '',
      ...tracks.take(20).toList().asMap().entries.map(
            (e) => '${e.key + 1}. ${e.value.title} — ${e.value.artist}',
          ),
      if (tracks.length > 20) '...and ${tracks.length - 20} more',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playlist "$title" copied to clipboard',
            style: MelodiaTokens.footnote.copyWith(color: tokens.text),
          ),
          backgroundColor: tokens.surface2,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showNameAndDetailsDialog(PlaylistDetail pl) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final nameCtrl = TextEditingController(text: pl.name);
    final descCtrl = TextEditingController(text: pl.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Name and details',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: MelodiaTokens.body.copyWith(color: tokens.text),
              decoration: InputDecoration(
                labelText: 'Playlist name',
                labelStyle: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: tokens.separator),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: tokens.accent),
                ),
              ),
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              minLines: 1,
              style: MelodiaTokens.body.copyWith(color: tokens.text),
              decoration: InputDecoration(
                labelText: 'Details (optional)',
                labelStyle: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: tokens.separator),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: tokens.accent),
                ),
              ),
            ),
          ],
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
            style: FilledButton.styleFrom(backgroundColor: tokens.accent),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Save',
              style: MelodiaTokens.subhead.copyWith(
                color: Theme.of(dialogCtx).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final newName = nameCtrl.text.trim();
      final newDesc = descCtrl.text.trim();
      if (newName.isNotEmpty) {
        await ref.read(playlistsProvider.notifier).updatePlaylist(
              widget.playlistId,
              name: newName,
              description: newDesc,
            );
        ref.invalidate(playlistDetailProvider(widget.playlistId));
      }
    }
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  bool _isPlaylistActive(List<Track> tracks) {
    final currentVid = ref.read(playerControllerProvider).queue.currentTrack?.videoId;
    if (currentVid == null) return false;
    return tracks.any((t) => t.videoId == currentVid);
  }

  void _onPlayPausePressed(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final controller = ref.read(playerControllerProvider.notifier);
    final playerState = ref.read(playerControllerProvider);

    if (_isPlaylistActive(tracks)) {
      if (playerState.isPlaying) {
        controller.pause();
      } else {
        controller.resume();
      }
      return;
    }

    final isShuffle = playerState.queue.shuffle;
    final startIdx = isShuffle ? Random().nextInt(tracks.length) : 0;
    controller.playList(tracks, startIdx);
  }

  void _onShufflePressed(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final controller = ref.read(playerControllerProvider.notifier);

    if (_isPlaylistActive(tracks)) {
      controller.toggleShuffle();
      return;
    }

    controller.setShuffle(true);
    final startIdx = Random().nextInt(tracks.length);
    controller.playList(tracks, startIdx);
  }

  Future<void> _showDeletePlaylistDialog(PlaylistDetail pl) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          "Delete playlist '${pl.name}'?",
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Text(
          'Are you sure you want to delete this playlist? This action cannot be undone.',
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
            style: FilledButton.styleFrom(backgroundColor: tokens.destructive),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Delete Playlist',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(playlistsProvider.notifier).deletePlaylist(pl.id);
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete playlist. Please try again.',
                style: MelodiaTokens.footnote.copyWith(color: tokens.text),
              ),
              backgroundColor: tokens.destructive,
            ),
          );
        }
      }
    }
  }

  void _handleSwipeRemove(Track track, int index) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final vid = track.videoId;

    setState(() {
      _pendingRemovals.add(vid);
    });

    // 5-second undo toast
    final timer = Timer(const Duration(seconds: 5), () {
      if (_pendingRemovals.contains(vid)) {
        _pendingRemovals.remove(vid);
        _pendingTimers.remove(vid);
        ref.read(playlistDetailProvider(widget.playlistId).notifier).removeTrack(vid);
      }
    });
    _pendingTimers[vid] = timer;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed "${track.title}"',
          style: MelodiaTokens.footnote.copyWith(color: tokens.text),
        ),
        backgroundColor: tokens.surface2,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: tokens.accent,
          onPressed: () {
            _pendingTimers[vid]?.cancel();
            _pendingTimers.remove(vid);
            setState(() {
              _pendingRemovals.remove(vid);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final isDesktop =
        MediaQuery.of(context).size.width >= MelodiaTokens.breakpointTablet;

    if (widget.isLikedSongs) {
      return _buildLikedSongsView(tokens, isDesktop);
    }
    return _buildCustomPlaylistView(tokens, isDesktop);
  }

  // ---------------------------------------------------------------------------
  // Custom Playlist View
  // ---------------------------------------------------------------------------

  Widget _buildCustomPlaylistView(MelodiaTokens tokens, bool isDesktop) {
    final detailAsync = ref.watch(playlistDetailProvider(widget.playlistId));

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tokens.accent),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (detailAsync.valueOrNull != null) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (_isEditing) {
                    _nameController.text = detailAsync.value!.name;
                  } else {
                    final trimmed = _nameController.text.trim();
                    if (trimmed.isNotEmpty &&
                        trimmed != detailAsync.value!.name) {
                      ref
                          .read(playlistsProvider.notifier)
                          .updatePlaylist(widget.playlistId, name: trimmed);
                    }
                  }
                });
              },
              child: Text(
                _isEditing ? 'Done' : 'Edit',
                style: MelodiaTokens.headline.copyWith(color: tokens.accent),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: tokens.accent),
              color: tokens.surface,
              onSelected: (val) {
                if (val == 'rename') {
                  setState(() {
                    _isEditing = true;
                    _nameController.text = detailAsync.value!.name;
                  });
                } else if (val == 'add') {
                  context.push('/search');
                } else if (val == 'delete') {
                  _showDeletePlaylistDialog(detailAsync.value!);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: tokens.text, size: 20),
                      const SizedBox(width: MelodiaTokens.spacingSm),
                      Text('Rename',
                          style:
                              MelodiaTokens.body.copyWith(color: tokens.text)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: tokens.text, size: 20),
                      const SizedBox(width: MelodiaTokens.spacingSm),
                      Text('Add Songs',
                          style:
                              MelodiaTokens.body.copyWith(color: tokens.text)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: tokens.destructive, size: 20),
                      const SizedBox(width: MelodiaTokens.spacingSm),
                      Text('Delete Playlist',
                          style: MelodiaTokens.body
                              .copyWith(color: tokens.destructive)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: detailAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
          ),
        ),
        error: (err, _) {
          if (err is ApiError && err is UnknownError) {
            return Center(
              child: Text(
                'Playlist not found.',
                style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load playlist.',
                  style:
                      MelodiaTokens.body.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                FilledButton(
                  onPressed: () => ref.invalidate(
                      playlistDetailProvider(widget.playlistId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        data: (pl) {
          final visibleItems = pl.tracks.items
              .where((it) => !_pendingRemovals.contains(it.track.videoId))
              .toList();

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MelodiaTokens.spacingLg,
                    vertical: MelodiaTokens.spacingSm,
                  ),
                  child: isDesktop
                      ? _buildDesktopHeader(pl, visibleItems, tokens)
                      : _buildMobileHeader(pl, visibleItems, tokens),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: MelodiaTokens.spacingLg),
              ),
              if (_isEditing)
                _buildReorderableTrackList(visibleItems, tokens)
              else
                _buildNormalTrackList(visibleItems, tokens),
              if (pl.tracks.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120), // Bottom inset for mini player
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _deriveCovers(PlaylistDetail pl, List<PlaylistTrackItem> visibleItems) {
    final fromTracks = visibleItems
        .map((it) => it.track.thumbnail)
        .where((t) => t != null && t.isNotEmpty)
        .cast<String>()
        .take(4)
        .toList();
    return fromTracks.isNotEmpty ? fromTracks : pl.coverThumbnails;
  }

  // Mobile Header (Apple Music themed, clean background)
  Widget _buildMobileHeader(
      PlaylistDetail pl, List<PlaylistTrackItem> visibleItems, MelodiaTokens tokens) {
    final trackCount = pl.trackCount;
    final durationStr = _formatTotalDuration(pl.durationSeconds);
    final tracks = visibleItems.map((it) => it.track).toList();
    final covers = _deriveCovers(pl, visibleItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: MosaicCover(
            coverThumbnails: covers,
            size: 200,
          ),
        ),
          const SizedBox(height: MelodiaTokens.spacingLg),
          if (_isEditing)
            TextField(
              controller: _nameController,
              style: MelodiaTokens.title2.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Playlist Name',
                hintStyle:
                    MelodiaTokens.title2.copyWith(color: tokens.textTertiary),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: tokens.accent),
                ),
              ),
            )
          else
            Text(
              pl.name,
              style: MelodiaTokens.title2.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (pl.description != null && pl.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              pl.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.public_rounded, size: 14, color: tokens.textSecondary),
              const SizedBox(width: 6),
              Text(
                '$trackCount ${trackCount == 1 ? 'song' : 'songs'}$durationStr',
                style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: MelodiaTokens.spacingMd),
          _buildActionRow(
            collectionKey: 'playlist:${widget.playlistId}',
            title: pl.name,
            tracks: tracks,
            tokens: tokens,
          ),
          const SizedBox(height: MelodiaTokens.spacingMd),
          _buildFeaturePillsRow(pl, tokens),
        ],
      );
  }

  // Desktop Header
  Widget _buildDesktopHeader(
      PlaylistDetail pl, List<PlaylistTrackItem> visibleItems, MelodiaTokens tokens) {
    final trackCount = pl.trackCount;
    final durationStr = _formatTotalDuration(pl.durationSeconds);
    final tracks = visibleItems.map((it) => it.track).toList();
    final covers = _deriveCovers(pl, visibleItems);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MosaicCover(
          coverThumbnails: covers,
          size: 200,
        ),
        const SizedBox(width: MelodiaTokens.spacingXl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAYLIST',
                style: MelodiaTokens.caption.copyWith(
                  color: tokens.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              if (_isEditing)
                TextField(
                  controller: _nameController,
                  style: MelodiaTokens.largeTitle.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Playlist Name',
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: tokens.accent),
                    ),
                  ),
                )
              else
                Text(
                  pl.name,
                  style: MelodiaTokens.largeTitle.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (pl.description != null && pl.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  pl.description!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '$trackCount ${trackCount == 1 ? 'song' : 'songs'}$durationStr',
                style: MelodiaTokens.footnote.copyWith(color: tokens.accent),
              ),
              const SizedBox(height: MelodiaTokens.spacingMd),
              _buildActionRow(
                collectionKey: 'playlist:${widget.playlistId}',
                title: pl.name,
                tracks: tracks,
                tokens: tokens,
              ),
              const SizedBox(height: MelodiaTokens.spacingMd),
              _buildFeaturePillsRow(pl, tokens),
            ],
          ),
        ),
      ],
    );
  }

  // Action Row: Download icon (whole playlist) + Share icon on left, Shuffle + Play/Pause circle on right
  Widget _buildActionRow({
    required String collectionKey,
    required String title,
    required List<Track> tracks,
    required MelodiaTokens tokens,
  }) {
    final playerState = ref.watch(playerControllerProvider);
    final isShuffle = playerState.queue.shuffle;
    final currentVid = playerState.queue.currentTrack?.videoId;
    final isThisPlaylistPlaying = currentVid != null &&
        tracks.any((t) => t.videoId == currentVid) &&
        playerState.isPlaying;

    return Row(
      children: [
        CollectionDownloadButton(
          collectionKey: collectionKey,
          title: title,
          tracks: tracks,
          compact: true,
        ),
        IconButton(
          tooltip: 'Share playlist',
          icon: Icon(
            Icons.share_outlined,
            size: 24,
            color: tokens.textSecondary,
          ),
          onPressed: () => _sharePlaylist(title, tracks),
        ),
        const Spacer(),
        IconButton(
          tooltip: isShuffle ? 'Shuffle on' : 'Shuffle off',
          icon: Icon(
            Icons.shuffle_rounded,
            size: 24,
            color: isShuffle ? tokens.accent : tokens.textSecondary,
          ),
          onPressed: tracks.isEmpty ? null : () => _onShufflePressed(tracks),
        ),
        const SizedBox(width: MelodiaTokens.spacingSm),
        Material(
          color: tokens.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: tracks.isEmpty ? null : () => _onPlayPausePressed(tracks),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                isThisPlaylistPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 30,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Feature Pill Buttons Row: + Add | Edit | Name and details
  Widget _buildFeaturePillsRow(PlaylistDetail pl, MelodiaTokens tokens) {
    Widget buildPill({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isActive = false,
    }) {
      return Material(
        color: isActive ? tokens.accent.withValues(alpha: 0.16) : tokens.surface2,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? tokens.accent : tokens.text,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: MelodiaTokens.subhead.copyWith(
                    color: isActive ? tokens.accent : tokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          buildPill(
            icon: Icons.add_rounded,
            label: 'Add',
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: MelodiaTokens.spacingSm),
          buildPill(
            icon: _isEditing ? Icons.check_rounded : Icons.menu_rounded,
            label: _isEditing ? 'Done' : 'Edit',
            isActive: _isEditing,
            onTap: () {
              setState(() {
                _isEditing = !_isEditing;
                if (_isEditing) {
                  _nameController.text = pl.name;
                } else {
                  final trimmed = _nameController.text.trim();
                  if (trimmed.isNotEmpty && trimmed != pl.name) {
                    ref
                        .read(playlistsProvider.notifier)
                        .updatePlaylist(widget.playlistId, name: trimmed);
                  }
                }
              });
            },
          ),
          const SizedBox(width: MelodiaTokens.spacingSm),
          buildPill(
            icon: Icons.edit_outlined,
            label: 'Name and details',
            onTap: () => _showNameAndDetailsDialog(pl),
          ),
        ],
      ),
    );
  }

  // Normal Track List
  Widget _buildNormalTrackList(
      List<PlaylistTrackItem> items, MelodiaTokens tokens) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingXl,
          ),
          child: Center(
            child: Text(
              'No tracks in this playlist yet.',
              style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
            ),
          ),
        ),
      );
    }

    final playerState = ref.watch(playerControllerProvider);
    final currentVid = playerState.queue.currentTrack?.videoId;
    final isPlaying = playerState.isPlaying;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final it = items[index];
          final trk = it.track;
          final isCurrent = trk.videoId == currentVid;

          return Dismissible(
            key: ValueKey(trk.videoId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: MelodiaTokens.spacingLg),
              color: tokens.destructive,
              child: Icon(Icons.delete_outline_rounded,
                  color: tokens.text, size: 24),
            ),
            onDismissed: (_) => _handleSwipeRemove(trk, index),
            child: TrackRow(
              track: trk,
              index: index,
              isCurrentTrack: isCurrent,
              isPlaying: isPlaying,
              onTap: () {
                final allTracks = items.map((e) => e.track).toList();
                ref
                    .read(playerControllerProvider.notifier)
                    .playList(allTracks, index);
              },
              onRemoveFromPlaylist: () => _handleSwipeRemove(trk, index),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  // Edit Mode Reorderable Track List
  Widget _buildReorderableTrackList(
      List<PlaylistTrackItem> items, MelodiaTokens tokens) {
    return SliverToBoxAdapter(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          final updated = List<PlaylistTrackItem>.from(items);
          final moved = updated.removeAt(oldIndex);
          updated.insert(newIndex, moved);

          final newOrder = updated.map((e) => e.track.videoId).toList();
          ref
              .read(playlistDetailProvider(widget.playlistId).notifier)
              .reorder(newOrder);
        },
        itemBuilder: (context, index) {
          final it = items[index];
          final trk = it.track;

          return ListTile(
            key: ValueKey(trk.videoId),
            leading: IconButton(
              icon: Icon(Icons.remove_circle_outline_rounded,
                  color: tokens.destructive),
              onPressed: () {
                ref
                    .read(playlistDetailProvider(widget.playlistId).notifier)
                    .removeTrack(trk.videoId);
              },
            ),
            title: Text(
              trk.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.body.copyWith(color: tokens.text),
            ),
            subtitle: Text(
              trk.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle_rounded, color: tokens.textTertiary),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Liked Songs View
  // ---------------------------------------------------------------------------

  Widget _buildLikedSongsView(MelodiaTokens tokens, bool isDesktop) {
    final likedAsync = ref.watch(likedSongsProvider);

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
      body: likedAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
          ),
        ),
        error: (err, _) => Center(
          child: Text(
            'Failed to load Liked Songs.',
            style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
          ),
        ),
        data: (page) {
          final items = page.items;
          final tracks = items.map((it) => it.track).toList();
          final trackCount = items.length;

          final playerState = ref.watch(playerControllerProvider);
          final currentVid = playerState.queue.currentTrack?.videoId;
          final isPlaying = playerState.isPlaying;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MelodiaTokens.spacingLg,
                    vertical: MelodiaTokens.spacingSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: MosaicCover(
                          coverThumbnails: [],
                          size: 200,
                          isLikedSongs: true,
                        ),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingLg),
                      Text(
                        'Liked Songs',
                        style: MelodiaTokens.title2.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$trackCount ${trackCount == 1 ? 'song' : 'songs'}',
                        style: MelodiaTokens.footnote
                            .copyWith(color: tokens.textSecondary),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingMd),
                      _buildActionRow(
                        collectionKey: 'liked_songs',
                        title: 'Liked Songs',
                        tracks: tracks,
                        tokens: tokens,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: MelodiaTokens.spacingLg),
              ),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingLg,
                      vertical: MelodiaTokens.spacingXl,
                    ),
                    child: Center(
                      child: Text(
                        'No liked songs yet.',
                        style: MelodiaTokens.body
                            .copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final it = items[index];
                      final trk = it.track;
                      final isCurrent = trk.videoId == currentVid;

                      return TrackRow(
                        track: trk,
                        index: index,
                        isCurrentTrack: isCurrent,
                        isPlaying: isPlaying,
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playList(tracks, index);
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              if (page.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          );
        },
      ),
    );
  }
}
