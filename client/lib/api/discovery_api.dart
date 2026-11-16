import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'discovery_models.dart';
import 'errors.dart';
import 'models.dart';

final discoveryApiProvider = Provider<DiscoveryApi>((ref) {
  return DiscoveryApi(ref.watch(apiClientProvider));
});

class DiscoveryApi {
  const DiscoveryApi(this._client);

  final ApiClient _client;

  /// GET /search/suggestions?q=
  Future<List<String>> getSuggestions(String q) async {
    final res = await _client.get('/search/suggestions', queryParams: {'q': q});
    if (res is Map<String, dynamic>) {
      final list = res['suggestions'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toList() ?? const [];
    }
    return const [];
  }

  /// GET /search?q= (no filter -> grouped)
  Future<SearchGrouped> searchGrouped(String q) async {
    final res = await _client.get('/search', queryParams: {'q': q});
    return SearchGrouped.fromJson(res as Map<String, dynamic>);
  }

  /// GET /search?q=&filter= (filter in songs, albums, artists, playlists)
  Future<SearchFilter> searchFilter(String q, String filter) async {
    final res = await _client.get('/search', queryParams: {'q': q, 'filter': filter});
    return SearchFilter.fromJson(res as Map<String, dynamic>);
  }

  /// GET /discover/home
  Future<List<Shelf>> getHome() async {
    final res = await _client.get('/discover/home');
    if (res is Map<String, dynamic>) {
      final shelves = res['shelves'] as List<dynamic>?;
      return shelves?.map((e) => Shelf.fromJson(e as Map<String, dynamic>)).toList() ?? const [];
    }
    return const [];
  }

  /// GET /discover/charts
  Future<List<Shelf>> getCharts([String? country]) async {
    final params = country != null ? {'country': country} : null;
    final res = await _client.get('/discover/charts', queryParams: params);
    if (res is Map<String, dynamic>) {
      final shelves = res['shelves'] as List<dynamic>?;
      return shelves?.map((e) => Shelf.fromJson(e as Map<String, dynamic>)).toList() ?? const [];
    }
    return const [];
  }

  /// GET /discover/moods
  Future<MoodsResponse> getMoods() async {
    final res = await _client.get('/discover/moods');
    return MoodsResponse.fromJson(res as Map<String, dynamic>);
  }

  /// GET /discover/moods/{params}/playlists
  Future<List<MediaItem>> getMoodPlaylists(String params) async {
    final encoded = Uri.encodeComponent(params);
    final res = await _client.get('/discover/moods/$encoded/playlists');
    if (res is Map<String, dynamic>) {
      final items = res['playlists'] as List<dynamic>?;
      return items?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [];
    }
    return const [];
  }

  /// GET /albums/{browse_id}
  Future<AlbumDetail> getAlbum(String browseId) async {
    final res = await _client.get('/albums/$browseId');
    return AlbumDetail.fromJson(res as Map<String, dynamic>);
  }

  /// GET /artists/{channel_id}
  Future<ArtistDetail> getArtist(String channelId) async {
    final res = await _client.get('/artists/$channelId');
    return ArtistDetail.fromJson(res as Map<String, dynamic>);
  }

  /// GET /ytplaylists/{playlist_id}
  Future<YtPlaylistDetail> getYtPlaylist(String playlistId) async {
    final res = await _client.get('/ytplaylists/$playlistId');
    return YtPlaylistDetail.fromJson(res as Map<String, dynamic>);
  }

  /// GET /watch/{video_id}/radio
  Future<List<Track>> getWatchRadio(String videoId) async {
    final res = await _client.get('/watch/$videoId/radio');
    if (res is Map<String, dynamic>) {
      final tracks = res['tracks'] as List<dynamic>?;
      return tracks?.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList() ?? const [];
    }
    return const [];
  }

  /// GET /lyrics/{video_id}
  Future<Lyrics?> getLyrics(String videoId) async {
    try {
      final res = await _client.get('/lyrics/$videoId');
      if (res is Map<String, dynamic>) {
        return Lyrics.fromJson(res);
      }
      return null;
    } on UnknownError {
      // 404 resource not found
      return null;
    } catch (_) {
      return null;
    }
  }
}
