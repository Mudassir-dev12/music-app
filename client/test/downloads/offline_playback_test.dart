import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/downloads/download_models.dart';

void main() {
  group('Offline Playback Logic', () {
    final downloadedTrack = const Track(
      videoId: 'dl1',
      title: 'Downloaded Song',
      artist: 'Artist One',
      artists: [Artist(name: 'Artist One')],
      durationSeconds: 200,
      isExplicit: false,
    );

    final onlineTrack = const Track(
      videoId: 'online1',
      title: 'Online Song',
      artist: 'Artist Two',
      artists: [Artist(name: 'Artist Two')],
      durationSeconds: 210,
      isExplicit: false,
    );

    test('manifest lookup finds downloaded track', () {
      final manifest = DownloadManifest(tracks: {
        'dl1': ManifestTrack(
          videoId: 'dl1',
          title: 'Downloaded Song',
          artist: 'Artist One',
          durationSeconds: 200,
          byteSize: 5000000,
          downloadedAt: DateTime.now(),
        ),
      });

      expect(manifest.tracks.containsKey('dl1'), isTrue);
      expect(manifest.tracks.containsKey('online1'), isFalse);
    });

    test('offline queue filters out non-downloaded tracks', () {
      final manifest = DownloadManifest(tracks: {
        'dl1': ManifestTrack(
          videoId: 'dl1',
          title: 'Downloaded Song',
          artist: 'Artist One',
          durationSeconds: 200,
          byteSize: 5000000,
          downloadedAt: DateTime.now(),
        ),
      });

      final fullList = [downloadedTrack, onlineTrack];
      final offlineFiltered = fullList.where((t) => manifest.tracks.containsKey(t.videoId)).toList();

      expect(offlineFiltered.length, 1);
      expect(offlineFiltered.first.videoId, 'dl1');
    });
  });
}
