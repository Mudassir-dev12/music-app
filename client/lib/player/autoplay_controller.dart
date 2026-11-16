import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/discovery_api.dart';
import '../api/models.dart';

const String kAutoplayPrefKey = 'melodia_autoplay_enabled';

final autoplayEnabledProvider =
    StateNotifierProvider<AutoplayNotifier, bool>((ref) {
  return AutoplayNotifier();
});

class AutoplayNotifier extends StateNotifier<bool> {
  AutoplayNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(kAutoplayPrefKey) ?? true;
  }

  Future<void> toggle() async {
    setAutoplay(!state);
  }

  Future<void> setAutoplay(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoplayPrefKey, enabled);
  }
}

/// Helper function to fetch and filter candidate autoplay tracks.
Future<List<Track>> getAutoplayCandidates({
  required DiscoveryApi discoveryApi,
  required Track seedTrack,
  required List<Track> existingQueue,
}) async {
  try {
    final radioTracks = await discoveryApi.getWatchRadio(seedTrack.videoId);
    final existingIds = existingQueue.map((t) => t.videoId).toSet();
    existingIds.add(seedTrack.videoId);

    // Keep candidate tracks not already seen in queue
    final candidates = radioTracks.where((t) => !existingIds.contains(t.videoId)).toList();
    return candidates;
  } catch (_) {
    return const [];
  }
}
