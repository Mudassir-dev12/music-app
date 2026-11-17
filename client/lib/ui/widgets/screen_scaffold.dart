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
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                title,
                style: MelodiaTokens.title1.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: false,
              actions: trailing != null
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: MelodiaTokens.spacingLg,
                        ),
                        child: Center(child: trailing!),
                      ),
                    ]
                  : null,
            ),
            ...slivers,
          ],
        ),
      ),
    );
  }
}

