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

    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: MelodiaTokens.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: SectionHeader(
                    title: shelf.title,
                    subtitle: shelf.subtitle,
                  ),
                ),
                if (onSeeAll != null || (shelf.seeAllParams != null && shelf.seeAllParams!.isNotEmpty))
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: MelodiaTokens.spacingXs),
                      child: Text(
                        'See All',
                        style: MelodiaTokens.subhead.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingMd),
          AlbumCarousel(
            children: shelf.items.map((item) {
              return MediaItemCard(
                item: item,
                width: itemWidth,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
