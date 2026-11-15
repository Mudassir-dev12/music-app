import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    this.trailing,
    required this.slivers,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: tokens.background,
              pinned: true,
              expandedHeight: 100,
              elevation: 0,
              scrolledUnderElevation: 0,
              actions: trailing != null
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: MelodiaTokens.spacingLg,
                        ),
                        child: trailing!,
                      ),
                    ]
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(
                  left: MelodiaTokens.spacingLg,
                  bottom: MelodiaTokens.spacingMd,
                ),
                title: Text(
                  title,
                  style: MelodiaTokens.headline.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ...slivers,
          ],
        ),
      ),
    );
  }
}
