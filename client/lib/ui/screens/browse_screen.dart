import 'package:flutter/material.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_scaffold.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Browse',
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.grid_view_rounded,
            title: 'Browse Music',
            subtitle: 'Curated playlists, charts, and new releases coming in Phase 4.',
          ),
        ),
      ],
    );
  }
}
