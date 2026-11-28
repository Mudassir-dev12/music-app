/// Riverpod state providers for Phase 3 user data with optimistic mutations.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/user_api.dart';
import '../core/connectivity/connectivity_controller.dart';
import '../downloads/offline_cache.dart';
import '../downloads/offline_mode.dart';
import '../session/session_controller.dart';

// ---------------------------------------------------------------------------
// 1. Liked Track IDs
// ---------------------------------------------------------------------------

final likedIdsProvider =
    AsyncNotifierProvider<LikedIdsNotifier, Set<String>>(LikedIdsNotifier.new);

class LikedIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return <String>{};

    final api = ref.read(userApiProvider);
    final ids = await api.getLikedIds();
    return ids.toSet();
  }

  /// Optimistically toggles like state for [trackOrVideoId] (either a [Track] or a [String] videoId).
  Future<void> toggleLike(dynamic trackOrVideoId) async {
    final videoId = trackOrVideoId is Track ? trackOrVideoId.videoId : trackOrVideoId as String;
    final current = state.valueOrNull ?? <String>{};
    final wasLiked = current.contains(videoId);

    // 1. Optimistic update
    final optimistic = Set<String>.from(current);
    if (wasLiked) {
      optimistic.remove(videoId);
    } else {
      optimistic.add(videoId);
    }
    state = AsyncData(optimistic);

    // 2. Perform API call
    final api = ref.read(userApiProvider);
    try {
      if (wasLiked) {
        await api.unlikeTrack(videoId);
      } else {
        await api.likeTrack(videoId);
      }
    } catch (e, st) {
      // 3. Revert on failure
      state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  bool isLiked(String videoId) {
    return state.valueOrNull?.contains(videoId) ?? false;
  }
}

// ---------------------------------------------------------------------------
// 2. Playlists List
// ---------------------------------------------------------------------------

final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(PlaylistsNotifier.new);

class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  String get _userId => ref.read(sessionProvider).user?.id ?? 'default';

  Future<void> _saveCache(List<Playlist> list) async {
    await ref.read(offlineCacheServiceProvider).save<Map<String, dynamic>>(
      endpoint: 'playlists',
      userId: _userId,
      data: {'items': list.map((p) => p.toJson()).toList()},
    );
  }

  Future<List<Playlist>?> _loadCache() async {
    final cached = await ref.read(offlineCacheServiceProvider).load(
      endpoint: 'playlists',
      userId: _userId,
    );
    if (cached == null) return null;
    final rawItems = cached.data['items'] as List<dynamic>?;
    if (rawItems == null) return null;
    return rawItems
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Playlist>> build() async {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return <Playlist>[];

    final isOffline = !ref.read(connectivityProvider).isOnline ||
        ref.read(isOfflineModeProvider);
    if (isOffline) {
      return (await _loadCache()) ?? <Playlist>[];
    }

    final api = ref.read(userApiProvider);
    try {
      final list = await api.listPlaylists();
      await _saveCache(list);
      return list;
    } catch (_) {
      final cached = await _loadCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final api = ref.read(userApiProvider);
    final pl = await api.createPlaylist(name, description: description);
    final current = state.valueOrNull ?? <Playlist>[];
    final next = [pl, ...current];
    state = AsyncData(next);
    await _saveCache(next);
    return pl;
  }

  Future<void> deletePlaylist(String id) async {
    final current = state.valueOrNull ?? <Playlist>[];
    final optimistic = current.where((p) => p.id != id).toList();
    state = AsyncData(optimistic);

    final api = ref.read(userApiProvider);
    try {
      await api.deletePlaylist(id);
      await _saveCache(optimistic);
    } catch (e, st) {
      state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> renamePlaylist(String id, String name) async {
    await updatePlaylist(id, name: name);
  }

  Future<void> updatePlaylist(String id, {String? name, String? description}) async {
    final current = state.valueOrNull ?? <Playlist>[];
    final optimistic = current.map((p) {
      if (p.id == id) {
        return p.copyWith(name: name, description: description);
      }
      return p;
    }).toList();
    state = AsyncData(optimistic);

    final api = ref.read(userApiProvider);
    try {
      final updated = await api.updatePlaylist(id, name: name, description: description);
      final next = current.map((p) => p.id == id ? updated : p).toList();
      state = AsyncData(next);
      await _saveCache(next);
    } catch (e, st) {
      state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(userApiProvider);
      final list = await api.listPlaylists();
      await _saveCache(list);
      return list;
    });
  }
}

// ---------------------------------------------------------------------------
// 3. Playlist Detail (Family)
// ---------------------------------------------------------------------------

final playlistDetailProvider = AsyncNotifierProvider.family<
    PlaylistDetailNotifier, PlaylistDetail, String>(PlaylistDetailNotifier.new);

class PlaylistDetailNotifier
    extends FamilyAsyncNotifier<PlaylistDetail, String> {
  String get _userId => ref.read(sessionProvider).user?.id ?? 'default';

  List<String> _computeCovers(List<PlaylistTrackItem> items) {
    return items
        .map((it) => it.track.thumbnail)
        .where((t) => t != null && t.isNotEmpty)
        .cast<String>()
        .take(4)
        .toList();
  }

  Future<void> _saveCache(PlaylistDetail detail) async {
    await ref.read(offlineCacheServiceProvider).save<Map<String, dynamic>>(
      endpoint: 'playlist_$arg',
      userId: _userId,
      data: detail.toJson(),
    );
  }

  Future<PlaylistDetail?> _loadCache() async {
    final cached = await ref.read(offlineCacheServiceProvider).load(
      endpoint: 'playlist_$arg',
      userId: _userId,
    );
    if (cached == null) return null;
    return PlaylistDetail.fromJson(cached.data);
  }

  @override
  Future<PlaylistDetail> build(String arg) async {
    final isOffline = !ref.read(connectivityProvider).isOnline ||
        ref.read(isOfflineModeProvider);
    if (isOffline) {
      final cached = await _loadCache();
      if (cached != null) return cached;
    }

    final api = ref.read(userApiProvider);
    try {
      final detail = await api.getPlaylist(arg);
      await _saveCache(detail);
      return detail;
    } catch (_) {
      final cached = await _loadCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<PlaylistAddResult> addTracks(List<String> videoIds) async {
    final api = ref.read(userApiProvider);
    final res = await api.addTracksToPlaylist(arg, videoIds);
    // Refresh detail and playlist list stats
    final fetched = await api.getPlaylist(arg);
    final covers = _computeCovers(fetched.tracks.items);
    final updated = covers.isNotEmpty
        ? fetched.copyWith(coverThumbnails: covers)
        : fetched;
    state = AsyncData(updated);
    await _saveCache(updated);
    ref.read(playlistsProvider.notifier).refresh();
    return res;
  }

  Future<void> removeTrack(String videoId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistic removal
    final optimisticTracks = current.tracks.items
        .where((t) => t.track.videoId != videoId)
        .toList();
    // Renumber positions
    final renumbered = <PlaylistTrackItem>[];
    for (var i = 0; i < optimisticTracks.length; i++) {
      final t = optimisticTracks[i];
      renumbered.add(PlaylistTrackItem(
        position: i + 1,
        addedAt: t.addedAt,
        track: t.track,
      ));
    }

    final optimistic = current.copyWith(
      trackCount: current.trackCount > 0 ? current.trackCount - 1 : 0,
      coverThumbnails: _computeCovers(renumbered),
      tracks: Page(items: renumbered, nextCursor: current.tracks.nextCursor),
    );
    state = AsyncData(optimistic);

    final api = ref.read(userApiProvider);
    try {
      await api.removeTrackFromPlaylist(arg, videoId);
      await _saveCache(optimistic);
      ref.read(playlistsProvider.notifier).refresh();
    } catch (e, st) {
      state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> reorder(List<String> orderedVideoIds) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final byId = {for (final t in current.tracks.items) t.track.videoId: t};
    final reordered = <PlaylistTrackItem>[];
    for (var i = 0; i < orderedVideoIds.length; i++) {
      final item = byId[orderedVideoIds[i]];
      if (item != null) {
        reordered.add(PlaylistTrackItem(
          position: i + 1,
          addedAt: item.addedAt,
          track: item.track,
        ));
      }
    }

    final optimistic = current.copyWith(
      coverThumbnails: _computeCovers(reordered),
      tracks: Page(items: reordered, nextCursor: current.tracks.nextCursor),
    );
    state = AsyncData(optimistic);

    final api = ref.read(userApiProvider);
    try {
      await api.reorderPlaylist(arg, orderedVideoIds);
      await _saveCache(optimistic);
      ref.read(playlistsProvider.notifier).refresh();
    } catch (e, st) {
      state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.tracks.hasMore) return;

    final api = ref.read(userApiProvider);
    final nextPage = await api.getPlaylist(arg, cursor: current.tracks.nextCursor);
    final updated = current.copyWith(
      tracks: Page(
        items: [...current.tracks.items, ...nextPage.tracks.items],
        nextCursor: nextPage.tracks.nextCursor,
      ),
    );
    state = AsyncData(updated);
    await _saveCache(updated);
  }
}

// ---------------------------------------------------------------------------
// 4. Recently Played Tracks
// ---------------------------------------------------------------------------

final recentProvider =
    AsyncNotifierProvider<RecentNotifier, List<Track>>(RecentNotifier.new);

class RecentNotifier extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return <Track>[];

    final api = ref.read(userApiProvider);
    try {
      return await api.getRecent();
    } catch (_) {
      return <Track>[];
    }
  }

  Future<void> refresh() async {
    final api = ref.read(userApiProvider);
    final data = await api.getRecent();
    state = AsyncData(data);
  }
}

// ---------------------------------------------------------------------------
// 5. History (Paginated)
// ---------------------------------------------------------------------------

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, Page<HistoryItem>>(HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<Page<HistoryItem>> {
  @override
  Future<Page<HistoryItem>> build() async {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return const Page(items: []);

    final api = ref.read(userApiProvider);
    return await api.getHistory();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final api = ref.read(userApiProvider);
    final next = await api.getHistory(cursor: current.nextCursor);
    state = AsyncData(Page(
      items: [...current.items, ...next.items],
      nextCursor: next.nextCursor,
    ));
  }

  Future<void> deleteItem(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final optimistic = current.items.where((it) => it.id != id).toList();
    state = AsyncData(Page(items: optimistic, nextCursor: current.nextCursor));

    final api = ref.read(userApiProvider);
    try {
      await api.deleteHistoryItem(id);
      ref.read(recentProvider.notifier).refresh();
    } catch (e, st) {
      state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> clearHistory() async {
    final current = state.valueOrNull;
    state = const AsyncData(Page(items: []));

    final api = ref.read(userApiProvider);
    try {
      await api.clearHistory();
      ref.read(recentProvider.notifier).refresh();
    } catch (e, st) {
      if (current != null) state = AsyncData(current);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> refresh() async {
    final api = ref.read(userApiProvider);
    state = AsyncData(await api.getHistory());
  }
}

// ---------------------------------------------------------------------------
// 6. Liked Songs (Page)
// ---------------------------------------------------------------------------

final likedSongsProvider =
    AsyncNotifierProvider<LikedSongsNotifier, Page<LikedItem>>(LikedSongsNotifier.new);

class LikedSongsNotifier extends AsyncNotifier<Page<LikedItem>> {
  @override
  Future<Page<LikedItem>> build() async {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return const Page(items: []);

    final api = ref.read(userApiProvider);
    return await api.getLikes();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final api = ref.read(userApiProvider);
    final next = await api.getLikes(cursor: current.nextCursor);
    state = AsyncData(Page(
      items: [...current.items, ...next.items],
      nextCursor: next.nextCursor,
    ));
  }

  Future<void> refresh() async {
    final api = ref.read(userApiProvider);
    state = AsyncData(await api.getLikes());
  }
}
