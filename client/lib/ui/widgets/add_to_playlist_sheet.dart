import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../theme/tokens.dart';

/// Shows the "Add to Playlist" sheet or dialog.
Future<void> showAddToPlaylistSheet(BuildContext context, Track track) {
  final isDesktop =
      MediaQuery.of(context).size.width >= MelodiaTokens.breakpointTablet;

  if (isDesktop) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: _AddToPlaylistContent(track: track),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MelodiaTokens.radiusSheet),
      ),
    ),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: _AddToPlaylistContent(track: track),
    ),
  );
}

class _AddToPlaylistContent extends ConsumerStatefulWidget {
  const _AddToPlaylistContent({required this.track});

  final Track track;

  @override
  ConsumerState<_AddToPlaylistContent> createState() =>
      _AddToPlaylistContentState();
}

class _AddToPlaylistContentState extends ConsumerState<_AddToPlaylistContent> {
  Future<void> _showCreatePlaylistDialog() async {
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
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
              ],
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
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accent,
                ),
                onPressed: () async {
                  final trimmed = controller.text.trim();
                  if (trimmed.isEmpty) {
                    setDialogState(() {
                      errorMessage = 'Playlist name cannot be empty.';
                    });
                    return;
                  }
                  try {
                    final pl = await ref
                        .read(playlistsProvider.notifier)
                        .createPlaylist(trimmed);
                    // Add track to new playlist
                    await ref
                        .read(playlistDetailProvider(pl.id).notifier)
                        .addTracks([widget.track.videoId]);

                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop(); // pop dialog
                    }
                    if (mounted) {
                      Navigator.of(this.context).pop(); // pop sheet
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added to "${pl.name}"',
                            style: MelodiaTokens.footnote
                                .copyWith(color: tokens.text),
                          ),
                          backgroundColor: tokens.surface2,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } on ConflictError catch (e) {
                    setDialogState(() {
                      errorMessage = e.message;
                    });
                  } catch (e) {
                    setDialogState(() {
                      errorMessage = e.toString();
                    });
                  }
                },
                child: Text(
                  'Create Playlist',
                  style:
                      MelodiaTokens.subhead.copyWith(color: tokens.background),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playlistsAsync = ref.watch(playlistsProvider);

    return Material(
      color: tokens.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MelodiaTokens.spacingLg,
                vertical: MelodiaTokens.spacingMd,
              ),
              child: Row(
                children: [
                  Text(
                    'Add to Playlist',
                    style: MelodiaTokens.title3.copyWith(
                      color: tokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: tokens.separator),

            // "New Playlist" action row
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                ),
                child: Icon(Icons.add_rounded, color: tokens.accent, size: 24),
              ),
              title: Text(
                'New Playlist',
                style: MelodiaTokens.headline.copyWith(color: tokens.accent),
              ),
              onTap: () => _showCreatePlaylistDialog(),
            ),
            Divider(height: 1, thickness: 0.5, color: tokens.separator),

            // Playlists list
            Expanded(
              child: playlistsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Could not load playlists.',
                          style: MelodiaTokens.body
                              .copyWith(color: tokens.textSecondary),
                        ),
                        const SizedBox(height: MelodiaTokens.spacingMd),
                        FilledButton(
                          onPressed: () =>
                              ref.read(playlistsProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                        child: Text(
                          'No playlists yet. Tap "New Playlist" above to create one.',
                          textAlign: TextAlign.center,
                          style: MelodiaTokens.footnote
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final pl = playlists[index];
                      final thumb = pl.coverThumbnails.isNotEmpty
                          ? pl.coverThumbnails.first
                          : null;

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            MelodiaTokens.radiusArtworkSm,
                          ),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: thumb != null
                                ? CachedNetworkImage(
                                    imageUrl: thumb,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        Container(color: tokens.surface2),
                                    errorWidget: (_, __, ___) => Container(
                                      color: tokens.surface2,
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        color: tokens.textTertiary,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: tokens.surface2,
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: tokens.textTertiary,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MelodiaTokens.body.copyWith(
                            color: tokens.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${pl.trackCount} ${pl.trackCount == 1 ? 'song' : 'songs'}',
                          style: MelodiaTokens.footnote.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        onTap: () async {
                          try {
                            final res = await ref
                                .read(playlistDetailProvider(pl.id).notifier)
                                .addTracks([widget.track.videoId]);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              final msg = res.skipped.isNotEmpty
                                  ? 'Already in "${pl.name}"'
                                  : 'Added to "${pl.name}"';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    msg,
                                    style: MelodiaTokens.footnote
                                        .copyWith(color: tokens.text),
                                  ),
                                  backgroundColor: tokens.surface2,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } on ConflictError catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.message,
                                    style: MelodiaTokens.footnote
                                        .copyWith(color: tokens.text),
                                  ),
                                  backgroundColor: tokens.destructive,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not add to playlist. Please try again.',
                                    style: MelodiaTokens.footnote
                                        .copyWith(color: tokens.text),
                                  ),
                                  backgroundColor: tokens.destructive,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
