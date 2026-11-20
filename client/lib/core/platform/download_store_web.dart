import 'dart:async';
import 'download_store_interface.dart';

class WebDownloadStore implements DownloadStore {
  const WebDownloadStore({String? customBaseDir});

  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<DownloadWriter> openWriter(String videoId, {int startOffset = 0}) {
    throw UnsupportedError('Downloads are available in the mobile app.');
  }

  @override
  Future<void> finalize(String videoId, {String extension = 'm4a'}) {
    throw UnsupportedError('Downloads are available in the mobile app.');
  }

  @override
  Future<void> delete(String videoId) {
    throw UnsupportedError('Downloads are available in the mobile app.');
  }

  @override
  Future<bool> exists(String videoId) async => false;

  @override
  Future<int> sizeOf(String videoId) async => 0;

  @override
  Future<int> partSizeOf(String videoId) async => 0;

  @override
  Future<String?> pathFor(String videoId) async => null;

  @override
  Future<int> totalBytesUsed() async => 0;

  @override
  Future<void> writeThumbnail(String videoId, List<int> bytes) async {}

  @override
  Future<List<int>?> readThumbnail(String videoId) async => null;

  @override
  Future<void> writeManifest(String jsonContent) async {}

  @override
  Future<String?> readManifest() async => null;

  @override
  Future<void> archiveCorruptManifest() async {}

  @override
  Future<List<String>> listDownloadedVideoIds() async => [];

  @override
  Future<void> cleanupOrphanParts(Set<String> activeVideoIds) async {}

  @override
  Future<void> writeOfflineCache(String key, String jsonContent) async {}

  @override
  Future<String?> readOfflineCache(String key) async => null;

  @override
  Future<void> deleteOfflineCache(String key) async {}

  @override
  Future<void> clearOfflineCache() async {}

  @override
  Future<void> deleteAllDownloads() async {}
}

DownloadStore createDownloadStore({String? customBaseDir}) =>
    WebDownloadStore(customBaseDir: customBaseDir);

