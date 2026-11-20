import 'dart:async';

abstract class DownloadWriter {
  Future<void> add(List<int> bytes);
  Future<void> close();
}

abstract class DownloadStore {
  bool get isSupported;

  Future<void> init();

  Future<DownloadWriter> openWriter(String videoId, {int startOffset = 0});

  Future<void> finalize(String videoId, {String extension = 'm4a'});

  Future<void> delete(String videoId);

  Future<bool> exists(String videoId);

  Future<int> sizeOf(String videoId);

  Future<int> partSizeOf(String videoId);

  Future<String?> pathFor(String videoId);

  Future<int> totalBytesUsed();

  Future<void> writeThumbnail(String videoId, List<int> bytes);

  Future<List<int>?> readThumbnail(String videoId);

  Future<void> writeManifest(String jsonContent);

  Future<String?> readManifest();

  Future<void> archiveCorruptManifest();

  Future<List<String>> listDownloadedVideoIds();

  Future<void> cleanupOrphanParts(Set<String> activeVideoIds);

  Future<void> writeOfflineCache(String key, String jsonContent);

  Future<String?> readOfflineCache(String key);

  Future<void> deleteOfflineCache(String key);

  Future<void> clearOfflineCache();

  Future<void> deleteAllDownloads();
}

