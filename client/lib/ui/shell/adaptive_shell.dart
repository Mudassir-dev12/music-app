import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../widgets/connection_status_banner.dart';
import 'mini_player.dart';
import 'phone_tab_bar.dart';
import 'player_bar.dart';
import 'sidebar.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTap,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= MelodiaTokens.breakpointTablet;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: tokens.background,
            body: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(
                  child: Row(
                    children: [
                      DesktopSidebar(
                        currentIndex: currentIndex,
                        onTap: onTap,
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const DesktopPlayerBar(),
              ],
            ),
          );
        }

        // Phone & Tablet layout
        return Scaffold(
          backgroundColor: tokens.background,
          body: Column(
            children: [
              const ConnectionStatusBanner(),
              Expanded(child: child),
              const MiniPlayer(),
              PhoneTabBar(
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        );
      },
    );
  }
}

