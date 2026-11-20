import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/platform/download_store_native.dart';
import 'package:melodia/downloads/download_models.dart';

void main() {
  late Directory tempDir;
  late NativeDownloadStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('melodia_manifest_test_');
    store = NativeDownloadStore(customBaseDir: tempDir.path);
    await store.init();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('DownloadManifest serialization and deserialization', () {
    final now = DateTime.now();
    final manifest = DownloadManifest(
      schema: 1,
      tracks: {
        'track1': ManifestTrack(
          videoId: 'track1',
          title: 'Title 1',
          artist: 'Artist 1',
          artists: ['Artist 1', 'Featured'],
          album: 'Album 1',
          albumId: 'alb1',
          durationSeconds: 180,
          thumbnailFile: 'thumb.jpg',
          byteSize: 1024,
          extension: 'm4a',
          downloadedAt: now,
          collections: {'liked', 'playlist:p1'},
        ),
      },
    );

    final encoded = manifest.encode();
    final decoded = DownloadManifest.decode(encoded);

    expect(decoded.schema, equals(1));
    expect(decoded.tracks.length, equals(1));
    final t1 = decoded.tracks['track1']!;
    expect(t1.videoId, equals('track1'));
    expect(t1.title, equals('Title 1'));
    expect(t1.artists, equals(['Artist 1', 'Featured']));
    expect(t1.collections, contains('liked'));
    expect(t1.collections, contains('playlist:p1'));
  });

  test('Atomic manifest write and read via store', () async {
    final manifest = DownloadManifest(
      schema: 1,
      tracks: {
        'v1': ManifestTrack(
          videoId: 'v1',
          title: 'Song V1',
          artist: 'Artist V1',
          durationSeconds: 200,
          byteSize: 5000,
          downloadedAt: DateTime.now(),
        ),
      },
    );

    await store.writeManifest(manifest.encode());

    final content = await store.readManifest();
    expect(content, isNotNull);
    final restored = DownloadManifest.decode(content!);
    expect(restored.tracks.containsKey('v1'), isTrue);
  });

  test('Corrupt manifest is moved aside to corrupt file and rebuilt from folder', () async {
    // 1. Write corrupt manifest
    final manifestFile = File('${tempDir.path}/manifest.json');
    await manifestFile.writeAsString('{{{ INVALID JSON');

    // 2. Create actual downloaded track files in folder and an unknown extra file
    final songFile1 = File('${tempDir.path}/vSong1.m4a');
    await songFile1.writeAsBytes([1, 2, 3, 4, 5]);

    final songFile2 = File('${tempDir.path}/vSong2.mp3');
    await songFile2.writeAsBytes([6, 7, 8, 9]);

    final unknownFile = File('${tempDir.path}/random_notes.txt');
    await unknownFile.writeAsString('do not delete me');

    // 3. Move aside corrupt manifest
    await store.archiveCorruptManifest();
    expect(await manifestFile.exists(), isFalse);

    // Verify corrupt file was created
    final corruptFiles = tempDir
        .listSync()
        .where((f) => f.uri.pathSegments.last.startsWith('manifest.corrupt-'));
    expect(corruptFiles.length, equals(1));

    // 4. Rebuild from folder scan
    final scannedIds = await store.listDownloadedVideoIds();
    expect(scannedIds, contains('vSong1'));
    expect(scannedIds, contains('vSong2'));
    expect(scannedIds, isNot(contains('random_notes')));

    // 5. Unknown extra file was left completely alone
    expect(await unknownFile.exists(), isTrue);
  });
}

