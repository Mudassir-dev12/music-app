import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../data/user_data_providers.dart';
import '../../theme/tokens.dart';
import '../widgets/mosaic_cover.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

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
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                    if (context.mounted) {
                      context.push('/playlist/${pl.id}');
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        elevation: 0,
        title: Text(
          'Library',
          style: MelodiaTokens.largeTitle.copyWith(color: tokens.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: tokens.accent, size: 28),
            onPressed: () => _showNewPlaylistDialog(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.only(right: MelodiaTokens.spacingMd),
            child: GestureDetector(
              onTap: () => context.push('/settings'),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: tokens.accent, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: tokens.accent,
        backgroundColor: tokens.surface,
        onRefresh: () async {
          await ref.read(playlistsProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingSm,
          ),
          children: [
            // Apple Music style navigation rows
            _buildNavRow(
              context: context,
              tokens: tokens,
              icon: Icons.queue_music_rounded,
              title: 'Playlists',
              onTap: () {}, // Already on library playlists screen
            ),
            _buildNavRow(
              context: context,
              tokens: tokens,
              icon: Icons.favorite_rounded,
              title: 'Liked Songs',
              onTap: () => context.push('/playlist/liked'),
            ),
            _buildNavRow(
              context: context,
              tokens: tokens,
              icon: Icons.history_rounded,
              title: 'Recently Played',
              onTap: () => context.push('/history'),
            ),
            _buildNavRow(
              context: context,
              tokens: tokens,
              icon: Icons.download_done_rounded,
              title: 'Downloaded',
              subtitle: 'Coming in a later update',
              enabled: false,
              onTap: null,
            ),

            const SizedBox(height: MelodiaTokens.spacingXl),

            // Section: Playlists
            Text(
              'Playlists',
              style: MelodiaTokens.title3.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),

            playlistsAsync.when(
              loading: () => _buildSkeletons(tokens),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                  child: Column(
                    children: [
                      Text(
                        'Failed to load playlists.',
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: MelodiaTokens.spacingXxl,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: 48,
                            color: tokens.textTertiary,
                          ),
                          const SizedBox(height: MelodiaTokens.spacingMd),
                          Text(
                            'No Playlists',
                            style: MelodiaTokens.title3
                                .copyWith(color: tokens.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the + icon above to create your first playlist.',
                            style: MelodiaTokens.footnote
                                .copyWith(color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 600;
                    if (isDesktop) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: MelodiaTokens.spacingLg,
                          crossAxisSpacing: MelodiaTokens.spacingLg,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final pl = playlists[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(
                              MelodiaTokens.radiusCard,
                            ),
                            onTap: () => context.push('/playlist/${pl.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.0,
                                  child: MosaicCover(
                                    coverThumbnails: pl.coverThumbnails,
                                    size: 180,
                                  ),
                                ),
                                const SizedBox(height: MelodiaTokens.spacingSm),
                                Text(
                                  pl.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MelodiaTokens.body.copyWith(
                                    color: tokens.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${pl.trackCount} ${pl.trackCount == 1 ? 'song' : 'songs'}',
                                  style: MelodiaTokens.footnote.copyWith(
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: playlists.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(left: 68),
                        child: Container(
                          height: 0.5,
                          color: tokens.separator,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final pl = playlists[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 52,
                            height: 52,
                            child: MosaicCover(
                              coverThumbnails: pl.coverThumbnails,
                              size: 52,
                            ),
                          ),
                          title: Text(
                            pl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MelodiaTokens.body.copyWith(
                              color: tokens.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${pl.trackCount} ${pl.trackCount == 1 ? 'song' : 'songs'}',
                            style: MelodiaTokens.footnote.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: tokens.textTertiary,
                          ),
                          onTap: () => context.push('/playlist/${pl.id}'),
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 120), // Mini player inset
          ],
        ),
      ),
    );
  }

  Widget _buildNavRow({
    required BuildContext context,
    required MelodiaTokens tokens,
    required IconData icon,
    required String title,
    String? subtitle,
    bool enabled = true,
    required VoidCallback? onTap,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            icon,
            color: enabled ? tokens.accent : tokens.textTertiary,
            size: 26,
          ),
          title: Text(
            title,
            style: MelodiaTokens.headline.copyWith(
              color: enabled ? tokens.text : tokens.textTertiary,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: MelodiaTokens.caption.copyWith(
                    color: tokens.textTertiary,
                  ),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: enabled ? tokens.textTertiary : tokens.separator,
          ),
          enabled: enabled,
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Container(
            height: 0.5,
            color: tokens.separator,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletons(MelodiaTokens tokens) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: MelodiaTokens.spacingSm),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius:
                      BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                ),
              ),
              const SizedBox(width: MelodiaTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
