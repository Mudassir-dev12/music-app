import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/platform/audio_cache.dart';

final audioCacheProvider = Provider<AudioCache>((ref) {
  final cache = createAudioCache();
  cache.init();
  return cache;
});

