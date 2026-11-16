import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/discovery_models.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';

class TopResultCard extends ConsumerWidget {
  const TopResultCard({super.key, required this.item});

  final MediaItem item;

  void _onTap(BuildContext context, WidgetRef ref) {
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

    return Semantics(
      button: true,
      label: 'Top result: ${item.title}, ${item.subtitle ?? ""}',
      child: GestureDetector(
        onTap: () => _onTap(context, ref),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingSm,
          ),
          padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
            boxShadow: MelodiaTokens.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: isArtist
                    ? BorderRadius.circular(44)
                    : BorderRadius.circular(MelodiaTokens.radiusCard),
                child: Container(
                  width: 88,
                  height: 88,
                  color: tokens.surface2,
                  child: item.thumbnail != null && item.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnail!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            isArtist ? Icons.person_rounded : Icons.music_note_rounded,
                            color: tokens.textTertiary,
                            size: 40,
                          ),
                        )
                      : Icon(
                          isArtist ? Icons.person_rounded : Icons.music_note_rounded,
                          color: tokens.textTertiary,
                          size: 40,
                        ),
                ),
              ),
              const SizedBox(width: MelodiaTokens.spacingLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MelodiaTokens.spacingSm,
                        vertical: MelodiaTokens.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(MelodiaTokens.radiusArtworkSm),
                      ),
                      child: Text(
                        item.type.toTypeString().toUpperCase(),
                        style: MelodiaTokens.caption.copyWith(
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: MelodiaTokens.spacingSm),
                    Text(
                      item.title,
                      style: MelodiaTokens.headline.copyWith(
                        color: tokens.text,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: MelodiaTokens.spacingXs),
                      Text(
                        item.subtitle!,
                        style: MelodiaTokens.subhead.copyWith(
                          color: tokens.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MelodiaTokens.spacingSm),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.accent,
                ),
                child: Icon(
                  item.type == MediaItemType.song
                      ? Icons.play_arrow_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: tokens.text,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
