/// User data (history, likes, playlists) API endpoints.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

final userApiProvider = Provider<UserApi>((ref) {
  return UserApi(ref.watch(apiClientProvider));
});

class UserApi {
  const UserApi(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<HistoryItem> recordHistory({
    required String videoId,
    required int listenedSeconds,
    required String clientEventId,
  }) async {
    final data = await _client.post('/me/history', {
      'video_id': videoId,
      'listened_seconds': listenedSeconds,
      'client_event_id': clientEventId,
    });
    return HistoryItem.fromJson(data as Map<String, dynamic>);
  }

  Future<Page<HistoryItem>> getHistory({int limit = 50, String? cursor}) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    final data = await _client.get('/me/history', queryParams: query) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?)
            ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return Page(items: items, nextCursor: data['next_cursor'] as String?);
  }

  Future<List<Track>> getRecent({int limit = 20}) async {
    final data = await _client.get('/me/recent', queryParams: {'limit': limit});
    return (data as List<dynamic>)
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteHistoryItem(int id) async {
    await _client.delete('/me/history/$id');
  }

  Future<void> clearHistory() async {
    await _client.delete('/me/history');
  }

  // ---------------------------------------------------------------------------
  // Likes
  // ---------------------------------------------------------------------------

  Future<void> likeTrack(String videoId) async {
    await _client.put('/me/likes/$videoId');
  }

  Future<void> unlikeTrack(String videoId) async {
    await _client.delete('/me/likes/$videoId');
  }

  Future<List<String>> getLikedIds() async {
    final data = await _client.get('/me/likes/ids') as Map<String, dynamic>;
    return (data['ids'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [];
  }

  Future<Page<LikedItem>> getLikes({int limit = 50, String? cursor}) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    final data = await _client.get('/me/likes', queryParams: query) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?)
            ?.map((e) => LikedItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return Page(items: items, nextCursor: data['next_cursor'] as String?);
  }

  // ---------------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------------

  Future<List<Playlist>> listPlaylists() async {
    final data = await _client.get('/me/playlists') as List<dynamic>;
    return data.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final data = await _client.post('/me/playlists', {
      'name': name,
      if (description != null) 'description': description,
    });
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<PlaylistDetail> getPlaylist(String id, {int limit = 50, String? cursor}) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    final data = await _client.get('/me/playlists/$id', queryParams: query);
    return PlaylistDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<Playlist> updatePlaylist(String id, {String? name, String? description}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    final data = await _client.patch('/me/playlists/$id', body);
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePlaylist(String id) async {
    await _client.delete('/me/playlists/$id');
  }

  Future<PlaylistAddResult> addTracksToPlaylist(String id, List<String> videoIds) async {
    final data = await _client.post('/me/playlists/$id/tracks', {
      'video_ids': videoIds,
    });
    return PlaylistAddResult.fromJson(data as Map<String, dynamic>);
  }

  Future<void> removeTrackFromPlaylist(String id, String videoId) async {
    await _client.delete('/me/playlists/$id/tracks/$videoId');
  }

  Future<void> reorderPlaylist(String id, List<String> videoIds) async {
    await _client.put('/me/playlists/$id/tracks/reorder', {
      'video_ids': videoIds,
    });
  }

  // ---------------------------------------------------------------------------
  // Downloads
  // ---------------------------------------------------------------------------

  Future<DownloadLimits> getDownloadLimits() async {
    final data = await _client.get('/me/downloads/limits');
    return DownloadLimits.fromJson(data as Map<String, dynamic>);
  }
}
