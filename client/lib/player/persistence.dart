import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import 'player_state.dart';
import 'queue.dart';

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService();
});

class PersistenceService {
  static const String _kQueueKey = 'player_queue';
  static const String _kCurrentIndexKey = 'player_current_index';
  static const String _kShuffleKey = 'player_shuffle';
  static const String _kRepeatKey = 'player_repeat';
  static const String _kVolumeKey = 'player_volume';
  static const String _kPositionMsKey = 'player_position_ms';
  static const String _kRecentlyPlayedKey = 'recently_played_tracks';

  Timer? _debounceTimer;

  void saveStateDebounced(PlayerStateData state) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      saveState(state);
    });
  }

  Future<void> saveState(PlayerStateData state) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = jsonEncode(
      state.queue.queue.map((t) => t.toJson()).toList(),
    );
    await prefs.setString(_kQueueKey, queueJson);
    await prefs.setInt(_kCurrentIndexKey, state.queue.currentIndex);
    await prefs.setBool(_kShuffleKey, state.queue.shuffle);
    await prefs.setString(_kRepeatKey, state.queue.repeat.name);
    await prefs.setDouble(_kVolumeKey, state.volume);
    await prefs.setInt(_kPositionMsKey, state.position.inMilliseconds);
  }

  Future<({QueueState queue, Duration position, double volume})?> restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_kQueueKey);
      if (queueStr == null) return null;

      final list = jsonDecode(queueStr) as List<dynamic>;
      final tracks = list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
      final index = prefs.getInt(_kCurrentIndexKey) ?? -1;
      final shuffle = prefs.getBool(_kShuffleKey) ?? false;
      final repeatName = prefs.getString(_kRepeatKey) ?? 'off';
      final volume = prefs.getDouble(_kVolumeKey) ?? 1.0;
      final positionMs = prefs.getInt(_kPositionMsKey) ?? 0;

      final repeat = RepeatMode.values.firstWhere(
        (r) => r.name == repeatName,
        orElse: () => RepeatMode.off,
      );

      final queueState = QueueState(
        queue: tracks,
        currentIndex: index,
        playNextQueue: const [],
        history: const [],
        shuffle: shuffle,
        repeat: repeat,
        originalOrder: tracks,
      );

      return (
        queue: queueState,
        position: Duration(milliseconds: positionMs),
        volume: volume,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> addToRecentlyPlayed(Track track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getRecentlyPlayed();
      final updated = [
        track,
        ...currentList.where((t) => t.videoId != track.videoId),
      ];
      final trimmed = updated.take(20).toList();
      final json = jsonEncode(trimmed.map((t) => t.toJson()).toList());
      await prefs.setString(_kRecentlyPlayedKey, json);
    } catch (_) {}
  }

  Future<List<Track>> getRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kRecentlyPlayedKey);
      if (jsonStr == null) return const [];
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }
}

