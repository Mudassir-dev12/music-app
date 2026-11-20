import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/platform/download_store_native.dart';

void main() {
  late Directory tempDir;
  late NativeDownloadStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('melodia_download_test_');
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

  test('NativeDownloadStore isSupported returns true', () {
    expect(store.isSupported, isTrue);
  });

  test('NativeDownloadStore write part, append at offset, finalize and delete', () async {
    const videoId = 'testVid01';

    // 1. Write chunk 1
    final writer1 = await store.openWriter(videoId, startOffset: 0);
    await writer1.add([1, 2, 3, 4, 5]);
    await writer1.close();

    expect(await store.partSizeOf(videoId), 5);
    expect(await store.exists(videoId), isFalse);

    // 2. Append chunk 2 at offset 5
    final writer2 = await store.openWriter(videoId, startOffset: 5);
    await writer2.add([6, 7, 8, 9, 10]);
    await writer2.close();

    expect(await store.partSizeOf(videoId), 10);

    // 3. Finalize
    await store.finalize(videoId, extension: 'm4a');
    expect(await store.exists(videoId), isTrue);
    expect(await store.sizeOf(videoId), 10);
    expect(await store.partSizeOf(videoId), 0);

    final path = await store.pathFor(videoId);
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);

    // 4. Delete
    await store.delete(videoId);
    expect(await store.exists(videoId), isFalse);
    expect(await store.sizeOf(videoId), 0);
  });

  test('NativeDownloadStore thumbnail read and write', () async {
    const videoId = 'thumbVid01';
    final thumbBytes = [100, 101, 102, 103];

    await store.writeThumbnail(videoId, thumbBytes);
    final readBytes = await store.readThumbnail(videoId);
    expect(readBytes, equals(thumbBytes));
  });

  test('NativeDownloadStore totalBytesUsed and orphan part cleanup', () async {
    // Write orphan part
    final writer = await store.openWriter('orphanVid', startOffset: 0);
    await writer.add([1, 1, 1]);
    await writer.close();

    // Write active part
    final writerActive = await store.openWriter('activeVid', startOffset: 0);
    await writerActive.add([2, 2, 2, 2]);
    await writerActive.close();

    expect(await store.partSizeOf('orphanVid'), 3);
    expect(await store.partSizeOf('activeVid'), 4);
    expect(await store.totalBytesUsed(), greaterThanOrEqualTo(7));

    // Cleanup orphan parts
    await store.cleanupOrphanParts({'activeVid'});
    expect(await store.partSizeOf('orphanVid'), 0);
    expect(await store.partSizeOf('activeVid'), 4);
  });

  test('NativeDownloadStore offline cache read, write, and clear', () async {
    const key = 'test_cache_key';
    const content = '{"sample": 123}';

    await store.writeOfflineCache(key, content);
    final read = await store.readOfflineCache(key);
    expect(read, equals(content));

    await store.deleteOfflineCache(key);
    expect(await store.readOfflineCache(key), isNull);

    await store.writeOfflineCache('k1', 'val1');
    await store.writeOfflineCache('k2', 'val2');
    await store.clearOfflineCache();
    expect(await store.readOfflineCache('k1'), isNull);
    expect(await store.readOfflineCache('k2'), isNull);
  });
}

