import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class PhoneTabBar extends StatelessWidget {
  const PhoneTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    const items = [
      (icon: Icons.play_circle_fill_rounded, label: 'Listen Now'),
      (icon: Icons.grid_view_rounded, label: 'Browse'),
      (icon: Icons.library_music_rounded, label: 'Library'),
      (icon: Icons.search_rounded, label: 'Search'),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: tokens.separator,
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(bottom: bottomPadding),
          height: 49 + bottomPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              final color = isSelected ? tokens.accent : tokens.textSecondary;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: item.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: color,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: MelodiaTokens.caption.copyWith(
                            color: color,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
