import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'download_store_interface.dart';

class _NativeDownloadWriter implements DownloadWriter {
  final RandomAccessFile _raf;

  _NativeDownloadWriter(this._raf);

  @override
  Future<void> add(List<int> bytes) async {
    await _raf.writeFrom(bytes);
  }

  @override
  Future<void> close() async {
    await _raf.flush();
    await _raf.close();
  }
}

class NativeDownloadStore implements DownloadStore {
  final String? _customBaseDir;
  Directory? _baseDir;

  NativeDownloadStore({String? customBaseDir}) : _customBaseDir = customBaseDir;

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {
    if (_baseDir != null) return;
    final custom = _customBaseDir;
    if (custom != null) {
      _baseDir = Directory(custom);
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      _baseDir = Directory('${docDir.path}/downloads');
    }

    if (!await _baseDir!.exists()) {
      await _baseDir!.create(recursive: true);
    }
    final artDir = Directory('${_baseDir!.path}/art');
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    final cacheDir = Directory('${_baseDir!.path}/cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  File _audioFile(String videoId, [String extension = 'm4a']) {
    return File('${_baseDir!.path}/$videoId.$extension');
  }

  File _partFile(String videoId) {
    return File('${_baseDir!.path}/$videoId.part');
  }

  File _thumbFile(String videoId) {
    return File('${_baseDir!.path}/art/$videoId.jpg');
  }

  File _manifestFile() {
    return File('${_baseDir!.path}/manifest.json');
  }

  File _manifestTmpFile() {
    return File('${_baseDir!.path}/manifest.tmp');
  }

  File _cacheFile(String key) {
    // Sanitize key for filesystem
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${_baseDir!.path}/cache/$safeKey.json');
  }

  @override
  Future<DownloadWriter> openWriter(String videoId, {int startOffset = 0}) async {
    await init();
    final part = _partFile(videoId);
    final raf = await part.open(mode: FileMode.append);
    if (startOffset > 0) {
      await raf.setPosition(startOffset);
    } else {
      await raf.setPosition(await raf.length());
    }
    return _NativeDownloadWriter(raf);
  }

  @override
  Future<void> finalize(String videoId, {String extension = 'm4a'}) async {
    await init();
    final part = _partFile(videoId);
    if (!await part.exists()) {
      throw StateError('Part file for $videoId does not exist');
    }
    final target = _audioFile(videoId, extension);
    if (await target.exists()) {
      await target.delete();
    }
    await part.rename(target.path);
  }

  @override
  Future<void> delete(String videoId) async {
    await init();
    // Delete potential audio files (m4a, webm, mp3, mp4)
    final extensions = ['m4a', 'webm', 'mp3', 'mp4', 'opus'];
    for (final ext in extensions) {
      final f = _audioFile(videoId, ext);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    final part = _partFile(videoId);
    if (await part.exists()) {
      try {
        await part.delete();
      } catch (_) {}
    }
    final thumb = _thumbFile(videoId);
    if (await thumb.exists()) {
      try {
        await thumb.delete();
      } catch (_) {}
    }
  }

  @override
  Future<bool> exists(String videoId) async {
    await init();
    final extensions = ['m4a', 'webm', 'mp3', 'mp4', 'opus'];
    for (final ext in extensions) {
      final f = _audioFile(videoId, ext);
      if (await f.exists()) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<int> sizeOf(String videoId) async {
    await init();
    final extensions = ['m4a', 'webm', 'mp3', 'mp4', 'opus'];
    for (final ext in extensions) {
      final f = _audioFile(videoId, ext);
      if (await f.exists()) {
        return await f.length();
      }
    }
    return 0;
  }

  @override
  Future<int> partSizeOf(String videoId) async {
    await init();
    final part = _partFile(videoId);
    if (await part.exists()) {
      return await part.length();
    }
    return 0;
  }

  @override
  Future<String?> pathFor(String videoId) async {
    await init();
    final extensions = ['m4a', 'webm', 'mp3', 'mp4', 'opus'];
    for (final ext in extensions) {
      final f = _audioFile(videoId, ext);
      if (await f.exists()) {
        return f.path;
      }
    }
    return null;
  }

  @override
  Future<int> totalBytesUsed() async {
    await init();
    int total = 0;
    try {
      if (await _baseDir!.exists()) {
        await for (final entity in _baseDir!.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  @override
  Future<void> writeThumbnail(String videoId, List<int> bytes) async {
    await init();
    final thumb = _thumbFile(videoId);
    await thumb.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> readThumbnail(String videoId) async {
    await init();
    final thumb = _thumbFile(videoId);
    if (await thumb.exists()) {
      return await thumb.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> writeManifest(String jsonContent) async {
    await init();
    final tmp = _manifestTmpFile();
    await tmp.writeAsString(jsonContent, flush: true);
    final target = _manifestFile();
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  @override
  Future<String?> readManifest() async {
    await init();
    final f = _manifestFile();
    if (await f.exists()) {
      return await f.readAsString();
    }
    return null;
  }

  @override
  Future<void> archiveCorruptManifest() async {
    await init();
    final f = _manifestFile();
    if (await f.exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final corruptFile = File('${_baseDir!.path}/manifest.corrupt-$timestamp.json');
      try {
        await f.rename(corruptFile.path);
      } catch (_) {}
    }
  }

  @override
  Future<List<String>> listDownloadedVideoIds() async {
    await init();
    final videoIds = <String>{};
    if (await _baseDir!.exists()) {
      await for (final entity in _baseDir!.list(followLinks: false)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.endsWith('.m4a') ||
              name.endsWith('.webm') ||
              name.endsWith('.mp3') ||
              name.endsWith('.mp4') ||
              name.endsWith('.opus')) {
            final dotIdx = name.lastIndexOf('.');
            if (dotIdx > 0) {
              videoIds.add(name.substring(0, dotIdx));
            }
          }
        }
      }
    }
    return videoIds.toList();
  }

  @override
  Future<void> cleanupOrphanParts(Set<String> activeVideoIds) async {
    await init();
    if (await _baseDir!.exists()) {
      await for (final entity in _baseDir!.list(followLinks: false)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.endsWith('.part')) {
            final vid = name.substring(0, name.length - 5);
            if (!activeVideoIds.contains(vid)) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    }
  }

  @override
  Future<void> writeOfflineCache(String key, String jsonContent) async {
    await init();
    final f = _cacheFile(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonContent, flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  @override
  Future<String?> readOfflineCache(String key) async {
    await init();
    final f = _cacheFile(key);
    if (await f.exists()) {
      return await f.readAsString();
    }
    return null;
  }

  @override
  Future<void> deleteOfflineCache(String key) async {
    await init();
    final f = _cacheFile(key);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> clearOfflineCache() async {
    await init();
    final cacheDir = Directory('${_baseDir!.path}/cache');
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list(followLinks: false)) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<void> deleteAllDownloads() async {
    await init();
    if (await _baseDir!.exists()) {
      await for (final entity in _baseDir!.list(followLinks: false)) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
    // Recreate subdirectories
    await init();
  }
}

DownloadStore createDownloadStore({String? customBaseDir}) =>
    NativeDownloadStore(customBaseDir: customBaseDir);
