import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_cache_interface.dart';

class _CacheEntry {
  final String videoId;
  int size;
  int lastAccessed;
  bool isComplete;

  _CacheEntry({
    required this.videoId,
    required this.size,
    required this.lastAccessed,
    required this.isComplete,
  });

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'size': size,
        'last_accessed': lastAccessed,
        'is_complete': isComplete,
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
        videoId: json['video_id'] as String? ?? '',
        size: json['size'] as int? ?? 0,
        lastAccessed: json['last_accessed'] as int? ?? 0,
        isComplete: json['is_complete'] as bool? ?? false,
      );
}

class NativeAudioCache implements AudioCache {
  final String? _customBaseDir;
  int _capBytes;
  Directory? _cacheDir;
  final Map<String, _CacheEntry> _entries = {};
  Set<String> _pinned = {};
  bool _initialized = false;

  NativeAudioCache({String? customBaseDir, int? defaultCapBytes})
      : _customBaseDir = customBaseDir,
        _capBytes = defaultCapBytes ?? 500 * 1024 * 1024;

  @override
  bool get isSupported => true;

  File get _indexFile => File('${_cacheDir!.path}/audio_cache_index.json');

  @override
  Future<void> init() async {
    if (_initialized) return;

    if (_customBaseDir != null) {
      _cacheDir = Directory(_customBaseDir!);
    } else {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/cache/audio');
    }

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    _initialized = true;
    await _loadIndex();
    await _cleanupOrphans();
    await evictLruIfNeeded();
  }

  Future<void> _loadIndex() async {
    _entries.clear();
    final indexFile = _indexFile;
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data['cap_bytes'] is int) {
          _capBytes = data['cap_bytes'] as int;
        }
        final entriesJson = data['entries'] as Map<String, dynamic>?;
        if (entriesJson != null) {
          for (final entry in entriesJson.entries) {
            if (entry.value is Map<String, dynamic>) {
              final e = _CacheEntry.fromJson(entry.value as Map<String, dynamic>);
              if (e.videoId.isNotEmpty) {
                _entries[e.videoId] = e;
              }
            }
          }
        }
      } catch (_) {
        // Corrupt index file: archive / reset
        try {
          final corruptBackup = File('${indexFile.path}.corrupt');
          if (await corruptBackup.exists()) {
            await corruptBackup.delete();
          }
          await indexFile.rename(corruptBackup.path);
        } catch (_) {}
      }
    }

    // Verify existing files and populate unindexed files
    try {
      final entities = await _cacheDir!.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.endsWith('.m4a')) {
            final vid = name.substring(0, name.length - 4);
            if (!_entries.containsKey(vid)) {
              final length = await entity.length();
              if (length > 0) {
                _entries[vid] = _CacheEntry(
                  videoId: vid,
                  size: length,
                  lastAccessed: DateTime.now().millisecondsSinceEpoch,
                  isComplete: true,
                );
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveIndex() async {
    if (_cacheDir == null) return;
    try {
      final entriesMap = <String, dynamic>{};
      for (final e in _entries.values) {
        entriesMap[e.videoId] = e.toJson();
      }
      final data = {
        'cap_bytes': _capBytes,
        'entries': entriesMap,
      };
      final tempFile = File('${_indexFile.path}.tmp');
      await tempFile.writeAsString(jsonEncode(data), flush: true);
      if (await tempFile.exists()) {
        await tempFile.rename(_indexFile.path);
      }
    } catch (_) {}
  }

  Future<void> _cleanupOrphans() async {
    if (_cacheDir == null) return;
    try {
      final entities = await _cacheDir!.list().toList();
      final now = DateTime.now();
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.endsWith('.part') || name.endsWith('.tmp')) {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > const Duration(hours: 1)) {
              await entity.delete().catchError((_) => entity);
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  AudioSource createAudioSource(Uri uri, String videoId) {
    if (_cacheDir != null) {
      final file = File('${_cacheDir!.path}/$videoId.m4a');
      // ignore: experimental_member_use
      return LockCachingAudioSource(uri, cacheFile: file);
    }
    return AudioSource.uri(uri);
  }

  @override
  Future<String> getCacheFilePath(String videoId) async {
    if (!_initialized) await init();
    return '${_cacheDir!.path}/$videoId.m4a';
  }

  @override
  Future<String?> getCachedFilePath(String videoId) async {
    if (!_initialized) await init();
    final entry = _entries[videoId];
    if (entry != null && entry.isComplete) {
      final file = File('${_cacheDir!.path}/$videoId.m4a');
      if (await file.exists() && (await file.length()) > 0) {
        await recordAccess(videoId);
        return file.path;
      } else {
        _entries.remove(videoId);
        await _saveIndex();
      }
    }
    return null;
  }

  @override
  Future<bool> isFullyCached(String videoId) async {
    if (!_initialized) await init();
    final path = await getCachedFilePath(videoId);
    return path != null;
  }

  @override
  Future<void> markFullyCached(String videoId, {int? sizeBytes}) async {
    if (!_initialized) await init();
    final path = await getCacheFilePath(videoId);
    final file = File(path);
    int size = sizeBytes ?? 0;
    if (size <= 0 && await file.exists()) {
      size = await file.length();
    }
    _entries[videoId] = _CacheEntry(
      videoId: videoId,
      size: size,
      lastAccessed: DateTime.now().millisecondsSinceEpoch,
      isComplete: true,
    );
    await _saveIndex();
    await evictLruIfNeeded();
  }

  @override
  Future<void> recordAccess(String videoId) async {
    final entry = _entries[videoId];
    if (entry != null) {
      entry.lastAccessed = DateTime.now().millisecondsSinceEpoch;
      await _saveIndex();
    }
  }

  @override
  void pinTracks(Set<String> videoIds) {
    _pinned = Set.from(videoIds);
  }

  @override
  Future<int> totalBytesUsed() async {
    if (!_initialized) await init();
    int total = 0;
    for (final e in _entries.values) {
      total += e.size;
    }
    return total;
  }

  @override
  Future<void> evictLruIfNeeded({int? maxBytes}) async {
    if (!_initialized) await init();
    final limit = maxBytes ?? _capBytes;

    int total = await totalBytesUsed();
    if (total <= limit) return;

    // Sort entries by lastAccessed ascending (oldest first)
    final sortedEntries = _entries.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    for (final entry in sortedEntries) {
      if (total <= limit) break;
      if (_pinned.contains(entry.videoId)) {
        continue; // Do not evict pinned tracks
      }

      await deleteFile(entry.videoId);
      total -= entry.size;
    }

    await _saveIndex();
  }

  @override
  Future<void> deleteFile(String videoId) async {
    if (!_initialized) await init();
    _entries.remove(videoId);
    final file = File('${_cacheDir!.path}/$videoId.m4a');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    final partFile = File('${_cacheDir!.path}/$videoId.m4a.part');
    if (await partFile.exists()) {
      try {
        await partFile.delete();
      } catch (_) {}
    }
    await _saveIndex();
  }

  @override
  Future<void> clearCache() async {
    if (!_initialized) await init();
    final toDelete = _entries.keys.where((vid) => !_pinned.contains(vid)).toList();
    for (final vid in toDelete) {
      await deleteFile(vid);
    }
    await _saveIndex();
  }

  @override
  Future<int> getCapBytes() async => _capBytes;

  @override
  Future<void> setCapBytes(int bytes) async {
    _capBytes = bytes;
    await _saveIndex();
    await evictLruIfNeeded();
  }
}

AudioCache createAudioCache({String? customBaseDir, int? defaultCapBytes}) =>
    NativeAudioCache(customBaseDir: customBaseDir, defaultCapBytes: defaultCapBytes);

