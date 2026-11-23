import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/platform/audio_cache.dart';
import 'package:melodia/core/platform/audio_cache_stub.dart' as stub_lib;

void main() {
  group('NativeAudioCache', () {
    late Directory tempDir;
    late AudioCache cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('melodia_audio_cache_test_');
      cache = createAudioCache(customBaseDir: tempDir.path, defaultCapBytes: 1000);
      await cache.init();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isSupported is true on native', () {
      expect(cache.isSupported, isTrue);
    });

    test('stores fully cached track and retrieves it', () async {
      final path = await cache.getCacheFilePath('track1');
      final file = File(path);
      await file.writeAsBytes(List.filled(200, 1));

      expect(await cache.isFullyCached('track1'), isFalse);
      await cache.markFullyCached('track1');
      expect(await cache.isFullyCached('track1'), isTrue);

      final cachedPath = await cache.getCachedFilePath('track1');
      expect(cachedPath, equals(path));
      expect(await cache.totalBytesUsed(), equals(200));
    });

    test('LRU eviction evicts oldest accessed file when cap exceeded', () async {
      // Cap is 1000 bytes. Add 3 tracks of 400 bytes each.
      for (int i = 1; i <= 3; i++) {
        final path = await cache.getCacheFilePath('track$i');
        final file = File(path);
        await file.writeAsBytes(List.filled(400, i));
        await cache.markFullyCached('track$i');
        // stagger access time
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await cache.recordAccess('track$i');
      }

      // Total added is 1200, cap is 1000 -> track1 should be evicted first
      expect(await cache.isFullyCached('track1'), isFalse);
      expect(await cache.isFullyCached('track2'), isTrue);
      expect(await cache.isFullyCached('track3'), isTrue);
      expect(await cache.totalBytesUsed(), equals(800));
    });

    test('pinned tracks are never evicted even when cap exceeded', () async {
      // Pin track1
      cache.pinTracks({'track1'});

      for (int i = 1; i <= 3; i++) {
        final path = await cache.getCacheFilePath('track$i');
        final file = File(path);
        await file.writeAsBytes(List.filled(400, i));
        await cache.markFullyCached('track$i');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await cache.recordAccess('track$i');
      }

      // Since track1 is pinned, track2 should be evicted instead of track1
      expect(await cache.isFullyCached('track1'), isTrue);
      expect(await cache.isFullyCached('track2'), isFalse);
      expect(await cache.isFullyCached('track3'), isTrue);
    });

    test('corrupt index file is recovered gracefully', () async {
      final path = await cache.getCacheFilePath('track1');
      final file = File(path);
      await file.writeAsBytes(List.filled(100, 1));
      await cache.markFullyCached('track1');

      // Corrupt the index file
      final indexFile = File('${tempDir.path}/audio_cache_index.json');
      await indexFile.writeAsString('{ invalid_json ]');

      // Create a new cache instance on same dir
      final newCache = createAudioCache(customBaseDir: tempDir.path, defaultCapBytes: 1000);
      await newCache.init();

      // Should recover by scanning files on disk
      expect(await newCache.isFullyCached('track1'), isTrue);
    });

    test('clearCache removes unpinned tracks', () async {
      final p1 = await cache.getCacheFilePath('t1');
      await File(p1).writeAsBytes(List.filled(100, 1));
      await cache.markFullyCached('t1');

      final p2 = await cache.getCacheFilePath('t2');
      await File(p2).writeAsBytes(List.filled(100, 2));
      await cache.markFullyCached('t2');

      cache.pinTracks({'t1'});
      await cache.clearCache();

      expect(await cache.isFullyCached('t1'), isTrue);
      expect(await cache.isFullyCached('t2'), isFalse);
    });
  });

  group('DefaultAudioCache (stub / web)', () {
    test('stub reports unsupported and safe no-ops', () async {
      final stub = stub_lib.DefaultAudioCache();
      expect(stub.isSupported, isFalse);
      expect(await stub.isFullyCached('any'), isFalse);
      expect(await stub.getCachedFilePath('any'), isNull);
      expect(await stub.totalBytesUsed(), equals(0));
    });
  });
}
