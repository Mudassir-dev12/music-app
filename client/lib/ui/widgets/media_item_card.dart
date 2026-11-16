import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/discovery_models.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';

class MediaItemCard extends ConsumerWidget {
  const MediaItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 160,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final double width;

  void _defaultTap(BuildContext context, WidgetRef ref) {
    switch (item.type) {
      case MediaItemType.song:
        ref.read(playerControllerProvider.notifier).playTrack(item.toTrack());
        break;
      case MediaItemType.album:
        final id = item.browseId ?? item.id;
        if (id.isNotEmpty) context.push('/album/$id');
        break;
      case MediaItemType.artist:
        final id = item.browseId ?? item.id;
        if (id.isNotEmpty) context.push('/artist/$id');
        break;
      case MediaItemType.playlist:
        final id = item.playlistId ?? item.id;
        if (id.isNotEmpty) context.push('/ytplaylist/$id');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final isArtist = item.type == MediaItemType.artist;

    final imageWidget = Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        color: tokens.surface2,
        shape: isArtist ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isArtist
            ? null
            : BorderRadius.circular(MelodiaTokens.radiusCard),
        boxShadow: MelodiaTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: isArtist
            ? BorderRadius.circular(width / 2)
            : BorderRadius.circular(MelodiaTokens.radiusCard),
        child: item.thumbnail != null && item.thumbnail!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.thumbnail!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: tokens.surface2),
                errorWidget: (_, __, ___) => Icon(
                  isArtist ? Icons.person_rounded : Icons.music_note_rounded,
                  size: 48,
                  color: tokens.textTertiary,
                ),
              )
            : Icon(
                isArtist ? Icons.person_rounded : Icons.music_note_rounded,
                size: 48,
                color: tokens.textTertiary,
              ),
      ),
    );

    return Semantics(
      button: true,
      label: '${item.title}, ${item.subtitle ?? ""}',
      child: GestureDetector(
        onTap: onTap ?? () => _defaultTap(context, ref),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: isArtist
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              imageWidget,
              const SizedBox(height: MelodiaTokens.spacingSm),
              Text(
                item.title,
                style: MelodiaTokens.subhead.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: isArtist ? TextAlign.center : TextAlign.start,
              ),
              if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                const SizedBox(height: MelodiaTokens.spacingXs),
                Text(
                  item.subtitle!,
                  style: MelodiaTokens.footnote.copyWith(
                    color: tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isArtist ? TextAlign.center : TextAlign.start,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
