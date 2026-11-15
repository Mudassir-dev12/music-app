import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart' as config;
import '../../session/session_controller.dart';
import '../../theme/tokens.dart';

class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final session = ref.watch(sessionProvider);
    final user = session.user;

    const navItems = [
      (icon: Icons.play_circle_fill_rounded, label: 'Listen Now'),
      (icon: Icons.grid_view_rounded, label: 'Browse'),
      (icon: Icons.library_music_rounded, label: 'Library'),
      (icon: Icons.search_rounded, label: 'Search'),
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          right: BorderSide(
            color: tokens.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(MelodiaTokens.spacingXl),
            child: Text(
              config.appName,
              style: MelodiaTokens.title1.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingMd,
            ),
            child: Column(
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = currentIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                    ),
                    tileColor: isSelected
                        ? tokens.surface2
                        : tokens.transparent,
                    leading: Icon(
                      item.icon,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: MelodiaTokens.subhead.copyWith(
                        color: isSelected ? tokens.text : tokens.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    onTap: () => onTap(index),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingLg),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingXl,
            ),
            child: Text(
              'PLAYLISTS',
              style: MelodiaTokens.caption.copyWith(
                color: tokens.textTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MelodiaTokens.spacingXl),
            child: Text(
              'Playlists coming in Phase 3',
              style: MelodiaTokens.footnote.copyWith(
                color: tokens.textTertiary,
              ),
            ),
          ),
          const Spacer(),
          Divider(color: tokens.separator, height: 1),
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: tokens.accent,
                    child: Text(
                      (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                      style: MelodiaTokens.footnote.copyWith(
                        color: tokens.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: MelodiaTokens.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? user.email.split('@').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MelodiaTokens.footnote.copyWith(
                            color: tokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MelodiaTokens.caption.copyWith(
                            color: tokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.logout_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                    tooltip: 'Sign Out',
                    onPressed: () {
                      ref.read(sessionProvider.notifier).signOut();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
