import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../api/user_api.dart';
import 'download_manager.dart';
import 'download_models.dart';
import 'download_repository.dart';

class CollectionSyncNotifier extends StateNotifier<Map<String, CollectionSync>> {
  static const _kPrefKey = 'melodia_keep_offline_collections';
  final DownloadManager _downloadManager;
  final Ref _ref;
  SharedPreferences? _prefs;

  CollectionSyncNotifier(this._downloadManager, this._ref) : super({}) {
    _init();
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_kPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final map = <String, CollectionSync>{};
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            final val = entry.value as Map<String, dynamic>;
            map[entry.key] = CollectionSync(
              collectionKey: entry.key,
              title: val['title'] as String? ?? entry.key,
              keepOffline: val['keepOffline'] as bool? ?? false,
              totalTracks: val['totalTracks'] as int? ?? 0,
            );
          }
        }
        state = map;
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final jsonMap = state.map((k, v) => MapEntry(k, {
            'title': v.title,
            'keepOffline': v.keepOffline,
            'totalTracks': v.totalTracks,
          }));
      await _prefs?.setString(_kPrefKey, jsonEncode(jsonMap));
    } catch (_) {}
  }

  bool isKeepOffline(String collectionKey) {
    return state[collectionKey]?.keepOffline ?? false;
  }

  CollectionSync? getCollectionSync(String collectionKey, int currentTotal) {
    final existing = state[collectionKey];
    int downloadedCount = 0;
    for (final track in _downloadManager.manifest.tracks.values) {
      if (track.collections.contains(collectionKey)) {
        downloadedCount++;
      }
    }
    return CollectionSync(
      collectionKey: collectionKey,
      title: existing?.title ?? collectionKey,
      keepOffline: existing?.keepOffline ?? false,
      totalTracks: currentTotal,
      downloadedTracks: downloadedCount,
    );
  }

  Future<void> setKeepOffline({
    required String collectionKey,
    required String title,
    required List<Track> tracks,
    required bool enabled,
    bool removeFiles = false,
  }) async {
    final updated = Map<String, CollectionSync>.from(state);
    if (enabled) {
      updated[collectionKey] = CollectionSync(
        collectionKey: collectionKey,
        title: title,
        keepOffline: true,
        totalTracks: tracks.length,
      );
      state = updated;
      await _save();
      // Queue all tracks in collection
      await _downloadManager.enqueueTracks(tracks, collection: collectionKey);
    } else {
      updated[collectionKey] = CollectionSync(
        collectionKey: collectionKey,
        title: title,
        keepOffline: false,
        totalTracks: tracks.length,
      );
      state = updated;
      await _save();
      // Remove collection flag from downloads, and remove file if removeFiles is true
      await _downloadManager.removeCollection(collectionKey, removeFiles: removeFiles);
    }
  }

  Future<void> syncOnlineCollections() async {
    // Check all collections marked keepOffline and enqueue missing tracks
    for (final entry in state.entries) {
      if (entry.value.keepOffline) {
        if (entry.key == 'liked') {
          try {
            final likedList = await _ref.read(userApiProvider).getLikes(limit: 100);
            await _downloadManager.enqueueTracks(
              likedList.items.map((it) => it.track).toList(),
              collection: 'liked',
            );
          } catch (_) {}
        }
      }
    }
  }
}

final collectionSyncProvider =
    StateNotifierProvider<CollectionSyncNotifier, Map<String, CollectionSync>>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return CollectionSyncNotifier(manager, ref);
});

final collectionSyncNotifierProvider = collectionSyncProvider;
