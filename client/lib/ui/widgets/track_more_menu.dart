import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/discovery_api.dart';
import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import 'add_to_playlist_sheet.dart';

/// Shows the unified "more" action menu for a track.
void showTrackMoreMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
  VoidCallback? onRemoveFromPlaylist,
}) {
  final tokens = Theme.of(context).extension<MelodiaTokens>()!;
  final likedIds = ref.read(likedIdsProvider).valueOrNull ?? <String>{};
  final isLiked = likedIds.contains(track.videoId);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MelodiaTokens.radiusSheet),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MelodiaTokens.spacingSm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header showing track title & artist
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
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MelodiaTokens.headline
                              .copyWith(color: tokens.text),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MelodiaTokens.footnote
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: tokens.separator),

            // 1. Like / Unlike
            ListTile(
              leading: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? tokens.accent : tokens.textSecondary,
              ),
              title: Text(
                isLiked ? 'Unlike' : 'Like',
                style: MelodiaTokens.body.copyWith(
                  color: isLiked ? tokens.accent : tokens.text,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
                ref.read(likedIdsProvider.notifier).toggleLike(track);
              },
            ),

            // 2. Add to Playlist
            ListTile(
              leading: Icon(Icons.playlist_add_rounded, color: tokens.accent),
              title: Text(
                'Add to Playlist',
                style: MelodiaTokens.body.copyWith(color: tokens.text),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showAddToPlaylistSheet(context, track);
              },
            ),

            // 3. Play Next
            ListTile(
              leading:
                  Icon(Icons.playlist_play_rounded, color: tokens.textSecondary),
              title: Text(
                'Play Next',
                style: MelodiaTokens.body.copyWith(color: tokens.text),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playerControllerProvider.notifier).enqueueNext(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Playing next: "${track.title}"',
                      style: MelodiaTokens.footnote.copyWith(color: tokens.text),
                    ),
                    backgroundColor: tokens.surface2,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // 4. Add to Queue
            ListTile(
              leading:
                  Icon(Icons.queue_music_rounded, color: tokens.textSecondary),
              title: Text(
                'Add to Queue',
                style: MelodiaTokens.body.copyWith(color: tokens.text),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playerControllerProvider.notifier).enqueueLast(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added to queue: "${track.title}"',
                      style: MelodiaTokens.footnote.copyWith(color: tokens.text),
                    ),
                    backgroundColor: tokens.surface2,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // 5. Remove from Playlist (if passed)
            if (onRemoveFromPlaylist != null)
              ListTile(
                leading: Icon(Icons.playlist_remove_rounded,
                    color: tokens.destructive),
                title: Text(
                  'Remove from this Playlist',
                  style: MelodiaTokens.body.copyWith(color: tokens.destructive),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onRemoveFromPlaylist();
                },
              ),

            // 6. Start Radio
            ListTile(
              leading: Icon(Icons.radio_rounded, color: tokens.accent),
              title: Text(
                'Start Radio',
                style: MelodiaTokens.body.copyWith(color: tokens.text),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final radio = await ref.read(discoveryApiProvider).getWatchRadio(track.videoId);
                  if (radio.isNotEmpty) {
                    ref.read(playerControllerProvider.notifier).playQueue(radio, initialIndex: 0);
                  }
                } catch (_) {}
              },
            ),

            // 7. Go to Artist
            if (track.artists.isNotEmpty && track.artists.first.id != null)
              ListTile(
                leading: Icon(Icons.person_rounded, color: tokens.textSecondary),
                title: Text(
                  'Go to Artist',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/artist/${track.artists.first.id!}');
                },
              ),

            // 8. Go to Album
            if (track.albumId != null && track.albumId!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.album_rounded, color: tokens.textSecondary),
                title: Text(
                  'Go to Album',
                  style: MelodiaTokens.body.copyWith(color: tokens.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/album/${track.albumId!}');
                },
              ),

            // 9. Download (Coming soon in Phase 5)
            ListTile(
              leading: Icon(Icons.download_rounded, color: tokens.textTertiary),
              title: Text(
                'Download',
                style: MelodiaTokens.body.copyWith(color: tokens.textTertiary),
              ),
              subtitle: Text(
                'Coming soon',
                style: MelodiaTokens.caption.copyWith(color: tokens.textTertiary),
              ),
              enabled: false,
            ),
          ],
        ),
      ),
    ),
  );
}
