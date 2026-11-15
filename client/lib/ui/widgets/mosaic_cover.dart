import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 2x2 Mosaic artwork cover for playlists, single artwork for 1-3 tracks,
/// neutral placeholder if empty, or gradient with heart for Liked Songs.
class MosaicCover extends StatelessWidget {
  const MosaicCover({
    super.key,
    required this.coverThumbnails,
    this.size = 180.0,
    this.isLikedSongs = false,
  });

  final List<String> coverThumbnails;
  final double size;
  final bool isLikedSongs;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
        boxShadow: MelodiaTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
        child: _buildArtwork(tokens),
      ),
    );
  }

  Widget _buildArtwork(MelodiaTokens tokens) {
    // 1. Liked Songs heart gradient
    if (isLikedSongs) {
      final heartSize = size.isFinite ? size * 0.45 : 54.0;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.accent,
              tokens.surface2,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.favorite_rounded,
            color: tokens.text,
            size: heartSize,
          ),
        ),
      );
    }

    // 2. Empty placeholder
    if (coverThumbnails.isEmpty) {
      final iconSize = size.isFinite ? size * 0.4 : 48.0;
      return Container(
        color: tokens.surface2,
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: tokens.textTertiary,
            size: iconSize,
          ),
        ),
      );
    }

    // 3. 2x2 Mosaic for >= 4 tracks
    if (coverThumbnails.length >= 4) {
      final half = size / 2;
      return Column(
        children: [
          Row(
            children: [
              _thumbImage(coverThumbnails[0], half, tokens),
              _thumbImage(coverThumbnails[1], half, tokens),
            ],
          ),
          Row(
            children: [
              _thumbImage(coverThumbnails[2], half, tokens),
              _thumbImage(coverThumbnails[3], half, tokens),
            ],
          ),
        ],
      );
    }

    // 4. Single cover image if 1..3 tracks
    return _thumbImage(coverThumbnails.first, size, tokens);
  }

  Widget _thumbImage(String url, double s, MelodiaTokens tokens) {
    return SizedBox(
      width: s,
      height: s,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: tokens.surface2),
        errorWidget: (_, __, ___) => Container(
          color: tokens.surface2,
          child: Icon(
            Icons.music_note_rounded,
            color: tokens.textTertiary,
            size: s * 0.4,
          ),
        ),
      ),
    );
  }
}
