import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class AlbumCarousel extends StatelessWidget {
  const AlbumCarousel({
    super.key,
    required this.children,
    this.height = 235,
    this.itemSpacing = MelodiaTokens.spacingMd,
  });

  final List<Widget> children;
  final double height;
  final double itemSpacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MelodiaTokens.spacingLg,
        ),
        itemCount: children.length,
        separatorBuilder: (_, __) => SizedBox(width: itemSpacing),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

