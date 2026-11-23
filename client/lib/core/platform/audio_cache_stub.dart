import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'audio_cache_interface.dart';

class DefaultAudioCache implements AudioCache {
  final String? _customBaseDir;
  int _capBytes;

  DefaultAudioCache({String? customBaseDir, int? defaultCapBytes})
      : _customBaseDir = customBaseDir,
        _capBytes = defaultCapBytes ?? 500 * 1024 * 1024;

  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> isFullyCached(String videoId) async => false;

  @override
  Future<String?> getCachedFilePath(String videoId) async => null;

  @override
  Future<String> getCacheFilePath(String videoId) async => '';

  @override
  AudioSource createAudioSource(Uri uri, String videoId) => AudioSource.uri(uri);

  @override
  Future<void> markFullyCached(String videoId, {int? sizeBytes}) async {}

  @override
  Future<void> recordAccess(String videoId) async {}

  @override
  Future<int> totalBytesUsed() async => 0;

  @override
  void pinTracks(Set<String> videoIds) {}

  @override
  Future<void> evictLruIfNeeded({int? maxBytes}) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> deleteFile(String videoId) async {}

  @override
  Future<int> getCapBytes() async => _capBytes;

  @override
  Future<void> setCapBytes(int bytes) async {
    _capBytes = bytes;
  }
}

AudioCache createAudioCache({String? customBaseDir, int? defaultCapBytes}) =>
    DefaultAudioCache(customBaseDir: customBaseDir, defaultCapBytes: defaultCapBytes);

