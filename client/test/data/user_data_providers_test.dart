import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/api/user_api.dart';
import 'package:melodia/data/user_data_providers.dart';
import 'package:melodia/session/session_controller.dart';

class MockUserApi implements UserApi {
  Set<String> likedIds = {'vid-1'};
  List<Playlist> playlists = [
    Playlist(
      id: 'pl-1',
      name: 'Chill Vibes',
      trackCount: 3,
      durationSeconds: 600,
      coverThumbnails: const [],
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
    ),
  ];

  bool shouldFailLike = false;
  bool shouldFailDelete = false;

  @override
  Future<List<String>> getLikedIds() async => likedIds.toList();

  @override
  Future<void> likeTrack(String videoId) async {
    if (shouldFailLike) throw Exception('Network error');
    likedIds.add(videoId);
  }

  @override
  Future<void> unlikeTrack(String videoId) async {
    if (shouldFailLike) throw Exception('Network error');
    likedIds.remove(videoId);
  }

  @override
  Future<List<Playlist>> listPlaylists() async => List.from(playlists);

  @override
  Future<void> deletePlaylist(String playlistId) async {
    if (shouldFailDelete) throw Exception('Delete error');
    playlists.removeWhere((p) => p.id == playlistId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const sampleTrack = Track(
    videoId: 'vid-2',
    title: 'Track 2',
    artists: [Artist(id: 'a1', name: 'Artist 2')],
    artist: 'Artist 2',
    isExplicit: false,
  );

  group('UserDataProviders - Optimistic updates & rollback', () {
    test('likedIdsProvider adds optimistically and persists on success',
        () async {
      final mock = MockUserApi();
      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWith((ref) => true),
          userApiProvider.overrideWithValue(mock),
        ],
      );

      // Initialize
      await container.read(likedIdsProvider.future);
      expect(container.read(likedIdsProvider).value, contains('vid-1'));
      expect(container.read(likedIdsProvider).value, isNot(contains('vid-2')));

      // Toggle like on vid-2
      final future =
          container.read(likedIdsProvider.notifier).toggleLike(sampleTrack);
      // Optimistic check immediately
      expect(container.read(likedIdsProvider).value, contains('vid-2'));

      await future;
      expect(container.read(likedIdsProvider).value, contains('vid-2'));
      expect(mock.likedIds, contains('vid-2'));
    });

    test('likedIdsProvider rolls back on failure', () async {
      final mock = MockUserApi()..shouldFailLike = true;
      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWith((ref) => true),
          userApiProvider.overrideWithValue(mock),
        ],
      );

      await container.read(likedIdsProvider.future);
      expect(container.read(likedIdsProvider).value, contains('vid-1'));

      try {
        await container.read(likedIdsProvider.notifier).toggleLike(sampleTrack);
      } catch (_) {}

      // Rolled back
      expect(container.read(likedIdsProvider).value, isNot(contains('vid-2')));
    });

    test('playlistsProvider deletes optimistically and rolls back on failure',
        () async {
      final mock = MockUserApi()..shouldFailDelete = true;
      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWith((ref) => true),
          userApiProvider.overrideWithValue(mock),
        ],
      );

      await container.read(playlistsProvider.future);
      expect(container.read(playlistsProvider).value?.length, equals(1));

      try {
        await container.read(playlistsProvider.notifier).deletePlaylist('pl-1');
      } catch (_) {}

      // Rolled back to original playlist list
      expect(container.read(playlistsProvider).value?.length, equals(1));
      expect(container.read(playlistsProvider).value?.first.id, equals('pl-1'));
    });
  });
}
