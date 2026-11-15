import 'package:flutter/material.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_scaffold.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Library',
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.library_music_rounded,
            title: 'Your Library',
            subtitle: 'Saved tracks, albums, and custom playlists coming in Phase 3.',
          ),
        ),
      ],
    );
  }
}
