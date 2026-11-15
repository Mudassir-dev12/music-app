import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/models.dart';
import '../../core/config.dart' as config;
import '../../data/user_data_providers.dart';
import '../../theme/tokens.dart';
import '../widgets/mosaic_cover.dart';

class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  Future<void> _showNewPlaylistDialog(BuildContext context, WidgetRef ref) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final controller = TextEditingController();
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
            ),
            title: Text(
              'New Playlist',
              style: MelodiaTokens.title3.copyWith(color: tokens.text),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              style: MelodiaTokens.body.copyWith(color: tokens.text),
              decoration: InputDecoration(
                hintText: 'Playlist name',
                hintStyle:
                    MelodiaTokens.body.copyWith(color: tokens.textTertiary),
                errorText: errorMessage,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(MelodiaTokens.radiusCard),
                  borderSide: BorderSide(color: tokens.separator),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(MelodiaTokens.radiusCard),
                  borderSide: BorderSide(color: tokens.accent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'Cancel',
                  style: MelodiaTokens.subhead
                      .copyWith(color: tokens.textSecondary),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accent,
                ),
                onPressed: () async {
                  final trimmed = controller.text.trim();
                  if (trimmed.isEmpty) return;

                  try {
                    final created = await ref
                        .read(playlistsProvider.notifier)
                        .createPlaylist(trimmed);
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                    if (context.mounted) {
                      context.push('/playlist/${created.id}');
                    }
                  } on ConflictError catch (e) {
                    setDialogState(() {
                      errorMessage = e.message;
                    });
                  } catch (e) {
                    setDialogState(() {
                      errorMessage = 'Failed to create playlist. Try again.';
                    });
                  }
                },
                child: Text(
                  'Create',
                  style: MelodiaTokens.subhead.copyWith(color: tokens.text),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, Playlist pl) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final controller = TextEditingController(text: pl.name);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Rename Playlist',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          style: MelodiaTokens.body.copyWith(color: tokens.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
              borderSide: BorderSide(color: tokens.separator),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
              borderSide: BorderSide(color: tokens.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style:
                  MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens.accent),
            onPressed: () async {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty && trimmed != pl.name) {
                await ref
                    .read(playlistsProvider.notifier)
                    .renamePlaylist(pl.id, trimmed);
              }
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: Text(
              'Save',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(
      BuildContext context, WidgetRef ref, Playlist pl) async {
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
              style:
                  MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
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

    if (confirmed == true) {
      await ref.read(playlistsProvider.notifier).deletePlaylist(pl.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playlistsAsync = ref.watch(playlistsProvider);

    const navItems = [
      (icon: Icons.play_circle_fill_rounded, label: 'Listen Now'),
      (icon: Icons.grid_view_rounded, label: 'Browse'),
      (icon: Icons.library_music_rounded, label: 'Library'),
      (icon: Icons.search_rounded, label: 'Search'),
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          right: BorderSide(
            color: tokens.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(MelodiaTokens.spacingXl),
            child: Text(
              config.appName,
              style: MelodiaTokens.title1.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingMd,
            ),
            child: Column(
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = currentIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(MelodiaTokens.radiusCard),
                    ),
                    tileColor:
                        isSelected ? tokens.surface2 : tokens.transparent,
                    leading: Icon(
                      item.icon,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: MelodiaTokens.subhead.copyWith(
                        color: isSelected ? tokens.text : tokens.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    onTap: () => onTap(index),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingLg),

          // Header for PLAYLISTS with + button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingXl,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PLAYLISTS',
                  style: MelodiaTokens.caption.copyWith(
                    color: tokens.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_rounded,
                    color: tokens.accent,
                    size: 20,
                  ),
                  tooltip: 'New Playlist',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showNewPlaylistDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingSm),

          // Liked Songs shortcut row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingMd,
            ),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
              ),
              leading: Icon(
                Icons.favorite_rounded,
                color: tokens.accent,
                size: 20,
              ),
              title: Text(
                'Liked Songs',
                style: MelodiaTokens.subhead.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => context.push('/playlist/liked'),
            ),
          ),

          // Playlists list
          Expanded(
            child: playlistsAsync.when(
              data: (playlists) {
                if (playlists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingXl,
                      vertical: MelodiaTokens.spacingMd,
                    ),
                    child: Text(
                      'No playlists yet',
                      style: MelodiaTokens.footnote.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MelodiaTokens.spacingMd,
                  ),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(MelodiaTokens.radiusCard),
                      ),
                      leading: SizedBox(
                        width: 24,
                        height: 24,
                        child: MosaicCover(
                          coverThumbnails: pl.coverThumbnails,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        pl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MelodiaTokens.subhead.copyWith(
                          color: tokens.text,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: tokens.textTertiary,
                          size: 16,
                        ),
                        color: tokens.surface,
                        onSelected: (val) {
                          if (val == 'rename') {
                            _showRenameDialog(context, ref, pl);
                          } else if (val == 'delete') {
                            _showDeleteDialog(context, ref, pl);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded,
                                    color: tokens.text, size: 18),
                                const SizedBox(width: MelodiaTokens.spacingSm),
                                Text('Rename',
                                    style: MelodiaTokens.body
                                        .copyWith(color: tokens.text)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: tokens.destructive, size: 18),
                                const SizedBox(width: MelodiaTokens.spacingSm),
                                Text('Delete',
                                    style: MelodiaTokens.body
                                        .copyWith(color: tokens.destructive)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/playlist/${pl.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MelodiaTokens.spacingXl,
                  vertical: MelodiaTokens.spacingMd,
                ),
                child: Text(
                  'Failed to load playlists',
                  style: MelodiaTokens.footnote.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Settings Row
          Divider(color: tokens.separator, height: 1),
          Padding(
            padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
              ),
              leading: Icon(
                Icons.settings_rounded,
                color: tokens.textSecondary,
                size: 20,
              ),
              title: Text(
                'Settings',
                style: MelodiaTokens.subhead.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              onTap: () => context.push('/settings'),
            ),
          ),
        ],
      ),
    );
  }
}
