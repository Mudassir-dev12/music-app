import 'package:flutter/material.dart';
import '../../api/discovery_models.dart';
import '../../theme/tokens.dart';
import 'carousel.dart';
import 'media_item_card.dart';
import 'section_header.dart';

class ShelfSection extends StatelessWidget {
  const ShelfSection({
    super.key,
    required this.shelf,
    this.onSeeAll,
    this.itemWidth = 150,
  });

  final Shelf shelf;
  final VoidCallback? onSeeAll;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    if (shelf.items.isEmpty) return const SizedBox.shrink();

    final hasSeeAll = onSeeAll != null ||
        (shelf.seeAllParams != null && shelf.seeAllParams!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: MelodiaTokens.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: shelf.title,
            subtitle: shelf.subtitle,
            onSeeAll: hasSeeAll ? onSeeAll : null,
          ),
          const SizedBox(height: MelodiaTokens.spacingMd),
          AlbumCarousel(
            children: shelf.items.map((item) {
              final isArtist = item.type == MediaItemType.artist;
              return MediaItemCard(
                item: item,
                width: isArtist ? 100 : itemWidth,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
