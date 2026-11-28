import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/data/user_data_providers.dart';
import 'package:melodia/theme/app_theme.dart';
import 'package:melodia/ui/screens/library_screen.dart';
import 'package:melodia/ui/screens/playlist_screen.dart';
import 'package:melodia/ui/widgets/mosaic_cover.dart';

class FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  Future<List<Playlist>> build() async {
    return [
      Playlist(
        id: 'pl-1',
        name: 'Rock Classics',
        trackCount: 10,
        durationSeconds: 2400,
        coverThumbnails: const [],
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
      ),
    ];
  }
}

class FakeLikedSongsNotifier extends LikedSongsNotifier {
  @override
  Future<Page<LikedItem>> build() async {
    return Page(
      items: [
        LikedItem(
          track: const Track(
            videoId: 'testVid0001',
            title: 'My Favorite Song',
            artists: [Artist(id: 'a1', name: 'Top Artist')],
            artist: 'Top Artist',
            durationSeconds: 180,
            isExplicit: false,
          ),
          likedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        ),
      ],
    );
  }
}

class FakeLikedIdsNotifier extends LikedIdsNotifier {
  @override
  Future<Set<String>> build() async => {'testVid0001'};
}

void main() {
  testWidgets('MosaicCover renders 2x2 grid when 4 covers available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: MosaicCover(
            coverThumbnails: [
              'https://example.com/1.jpg',
              'https://example.com/2.jpg',
              'https://example.com/3.jpg',
              'https://example.com/4.jpg',
            ],
            size: 180,
          ),
        ),
      ),
    );

    expect(find.byType(MosaicCover), findsOneWidget);
  });

  testWidgets('MosaicCover renders gradient with heart when isLikedSongs is true',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: MosaicCover(
            coverThumbnails: [],
            size: 180,
            isLikedSongs: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('LibraryScreen renders section header and nav rows',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Playlists'), findsWidgets);
    expect(find.text('Liked Songs'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Rock Classics'), findsOneWidget);
  });

  testWidgets('PlaylistScreen renders Liked Songs view', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedSongsProvider.overrideWith(FakeLikedSongsNotifier.new),
          likedIdsProvider.overrideWith(FakeLikedIdsNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const PlaylistScreen(playlistId: 'liked'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Liked Songs'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.text('My Favorite Song'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
