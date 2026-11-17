import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/api/music_api.dart';
import 'package:melodia/api/api_client.dart';
import 'package:melodia/core/platform/download_store_interface.dart';
import 'package:melodia/core/platform/network_type.dart';
import 'package:melodia/downloads/download_manager.dart';
import 'package:melodia/downloads/download_models.dart';

class InMemoryDownloadStore implements DownloadStore {
  final Map<String, List<int>> files = {};
  final Map<String, List<int>> tempFiles = {};
  final Map<String, String> cache = {};
  final Map<String, List<int>> thumbnails = {};
  String? manifestContent;

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {}

  @override
  Future<DownloadWriter> openWriter(String videoId, {String extension = 'm4a', int startOffset = 0}) async {
    final buffer = <int>[];
    if (tempFiles.containsKey(videoId)) {
      buffer.addAll(tempFiles[videoId]!);
    }
    return _InMemoryWriter(buffer, (data) {
      tempFiles[videoId] = data;
    });
  }

  @override
  Future<void> finalize(String videoId, {String extension = 'm4a'}) async {
    if (tempFiles.containsKey(videoId)) {
      files[videoId] = tempFiles.remove(videoId)!;
    }
  }

  @override
  Future<void> delete(String videoId) async {
    files.remove(videoId);
    tempFiles.remove(videoId);
  }

  Future<void> deleteTemp(String videoId) async {
    tempFiles.remove(videoId);
  }

  Future<bool> has(String videoId) async => files.containsKey(videoId);

  @override
  Future<bool> exists(String videoId) async => files.containsKey(videoId);

  @override
  Future<String?> pathFor(String videoId) async => files.containsKey(videoId) ? '/mock/$videoId.m4a' : null;

  @override
  Future<int> sizeOf(String videoId) async => files[videoId]?.length ?? 0;

  Future<int> tempSizeOf(String videoId) async => tempFiles[videoId]?.length ?? 0;

  @override
  Future<int> partSizeOf(String videoId) async => tempFiles[videoId]?.length ?? 0;

  @override
  Future<int> totalBytesUsed() async =>
      files.values.fold<int>(0, (sum, f) => sum + f.length);

  @override
  Future<String?> readManifest() async => manifestContent;

  @override
  Future<void> writeManifest(String content) async {
    manifestContent = content;
  }

  @override
  Future<void> archiveCorruptManifest() async {
    manifestContent = null;
  }

  Future<List<String>> listTrackIds() async => files.keys.toList();

  @override
  Future<List<String>> listDownloadedVideoIds() async => files.keys.toList();

  Future<void> cleanOrphans(Set<String> validIds) async {
    files.removeWhere((k, _) => !validIds.contains(k));
    tempFiles.clear();
  }

  @override
  Future<void> cleanupOrphanParts(Set<String> activeVideoIds) async {
    tempFiles.removeWhere((k, _) => !activeVideoIds.contains(k));
  }

  @override
  Future<void> deleteAllDownloads() async {
    files.clear();
    tempFiles.clear();
  }

  @override
  Future<void> writeThumbnail(String videoId, List<int> bytes) async {
    thumbnails[videoId] = bytes;
  }

  @override
  Future<List<int>?> readThumbnail(String videoId) async => thumbnails[videoId];

  @override
  Future<void> writeOfflineCache(String key, String jsonContent) async {
    cache[key] = jsonContent;
  }

  @override
  Future<String?> readOfflineCache(String key) async => cache[key];

  @override
  Future<void> deleteOfflineCache(String key) async {
    cache.remove(key);
  }

  @override
  Future<void> clearOfflineCache() async {
    cache.clear();
  }
}

class _InMemoryWriter implements DownloadWriter {
  final List<int> buffer;
  final void Function(List<int>) onCommit;

  _InMemoryWriter(this.buffer, this.onCommit);

  @override
  Future<void> add(List<int> chunk) async {
    buffer.addAll(chunk);
  }

  @override
  Future<void> close() async {
    onCommit(buffer);
  }
}

class FakeNetworkDetector implements NetworkTypeDetector {
  bool isWifiMode = true;

  Future<bool> isWifi() async => isWifiMode;

  Future<bool> isCellular() async => !isWifiMode;

  @override
  Future<bool> isNetworkAllowed({required bool wifiOnly}) async {
    if (!wifiOnly) return true;
    return isWifiMode;
  }

  @override
  Stream<bool> watchNetworkAllowed({required bool wifiOnly}) {
    return Stream.value(!wifiOnly || isWifiMode);
  }
}

void main() {
  group('DownloadManager', () {
    late InMemoryDownloadStore store;
    late FakeNetworkDetector networkDetector;
    late DownloadManager manager;

    const testTrack1 = Track(
      videoId: 'vid1',
      title: 'Track One',
      artist: 'Artist A',
      artists: [Artist(name: 'Artist A')],
      album: 'Album X',
      durationSeconds: 180,
      isExplicit: false,
    );

    const testTrack2 = Track(
      videoId: 'vid2',
      title: 'Track Two',
      artist: 'Artist B',
      artists: [Artist(name: 'Artist B')],
      album: 'Album Y',
      durationSeconds: 200,
      isExplicit: false,
    );

    setUp(() async {
      store = InMemoryDownloadStore();
      networkDetector = FakeNetworkDetector();
      manager = DownloadManager(
        store: store,
        musicApi: MusicApi(ApiClient()),
        apiClient: ApiClient(),
        networkDetector: networkDetector,
      );
      await manager.init(wifiOnly: false, storageCapMb: 100);
    });

    tearDown(() {
      manager.dispose();
    });

    test('enqueueTrack adds item to queue with queued status', () async {
      await manager.enqueueTrack(testTrack1);

      expect(manager.queue.length, 1);
      expect(manager.queue.first.videoId, 'vid1');
      expect(manager.queue.first.title, 'Track One');
    });

    test('enqueueTrack is idempotent: duplicate track is not re-added', () async {
      await manager.enqueueTrack(testTrack1);
      await manager.enqueueTrack(testTrack1);

      expect(manager.queue.length, 1);
    });

    test('cancel removes item from queue', () async {
      await manager.enqueueTrack(testTrack1);
      await manager.enqueueTrack(testTrack2);
      expect(manager.queue.length, 2);

      manager.cancel('vid1');
      expect(manager.queue.length, 1);
      expect(manager.queue.first.videoId, 'vid2');
    });

    test('downloadNext moves item to front of queued items', () async {
      await manager.enqueueTrack(testTrack1);
      await manager.enqueueTrack(testTrack2);

      expect(manager.queue[0].videoId, 'vid1');
      expect(manager.queue[1].videoId, 'vid2');

      manager.downloadNext('vid2');

      expect(manager.queue[0].videoId, 'vid2');
      expect(manager.queue[1].videoId, 'vid1');
    });

    test('pauseAll and resumeAll toggles isPaused state', () {
      expect(manager.isPaused, isFalse);

      manager.pauseAll();
      expect(manager.isPaused, isTrue);

      manager.resumeAll();
      expect(manager.isPaused, isFalse);
    });

    test('storage cap limit refuses download when cap is reached', () async {
      // Set storage cap to 1 MB
      manager.setStorageCapMb(1);

      // Pre-fill store with 2 MB of data
      store.files['existing'] = List.filled(2 * 1024 * 1024, 0);

      await manager.enqueueTrack(testTrack1);

      // Should be marked failed due to storage cap
      expect(manager.queue.length, 1);
      expect(manager.queue.first.status, DownloadStatus.failed);
      expect(manager.queue.first.failReason, FailReason.storageFull);
    });

    test('removeDownloadedTrack removes track from manifest and deletes file', () async {
      // Simulate downloaded track in store & manifest
      store.files['vid1'] = List.filled(1000, 1);
      final manifest = DownloadManifest(tracks: {
        'vid1': ManifestTrack(
          videoId: 'vid1',
          title: 'Track One',
          artist: 'Artist A',
          album: 'Album X',
          durationSeconds: 180,
          byteSize: 1000,
          downloadedAt: DateTime.now(),
        ),
      });
      await store.writeManifest(manifest.encode());
      await manager.init();

      expect(manager.manifest.tracks.containsKey('vid1'), isTrue);
      expect(await store.has('vid1'), isTrue);

      await manager.removeDownloadedTrack('vid1');

      expect(manager.manifest.tracks.containsKey('vid1'), isFalse);
      expect(await store.has('vid1'), isFalse);
    });
  });
}
