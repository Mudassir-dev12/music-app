import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.width = 160,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Semantics(
      button: onTap != null,
      label: '$title, ${subtitle ?? ""}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                child: Container(
                  width: width,
                  height: width,
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    boxShadow: MelodiaTokens.cardShadow,
                  ),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: tokens.surface2),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.music_note_rounded,
                            size: 48,
                            color: tokens.textTertiary,
                          ),
                        )
                      : Icon(
                          Icons.music_note_rounded,
                          size: 48,
                          color: tokens.textTertiary,
                        ),
                ),
              ),
              const SizedBox(height: MelodiaTokens.spacingSm),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MelodiaTokens.subhead.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MelodiaTokens.caption.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
