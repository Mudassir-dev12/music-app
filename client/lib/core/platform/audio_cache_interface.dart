import 'dart:async';
import 'package:just_audio/just_audio.dart';

abstract class AudioCache {
  bool get isSupported;

  Future<void> init();

  Future<bool> isFullyCached(String videoId);

  Future<String?> getCachedFilePath(String videoId);

  Future<String> getCacheFilePath(String videoId);

  AudioSource createAudioSource(Uri uri, String videoId);

  Future<void> markFullyCached(String videoId, {int? sizeBytes});

  Future<void> recordAccess(String videoId);

  Future<int> totalBytesUsed();

  void pinTracks(Set<String> videoIds);

  Future<void> evictLruIfNeeded({int? maxBytes});

  Future<void> clearCache();

  Future<void> deleteFile(String videoId);

  Future<int> getCapBytes();

  Future<void> setCapBytes(int bytes);
}
