/// Music / search / audio-ticket API calls.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final musicApiProvider = Provider<MusicApi>((ref) {
  return MusicApi(ref.watch(apiClientProvider));
});

// ---------------------------------------------------------------------------
// MusicApi
// ---------------------------------------------------------------------------

/// Wraps search, track, and audio-ticket endpoints.
class MusicApi {
  const MusicApi(this._client);

  final ApiClient _client;

  /// Search for tracks.
  ///
  /// [filter] defaults to `'songs'`; [limit] defaults to 25.
  Future<SearchResponse> search(
    String q, {
    String filter = 'songs',
    int limit = 25,
  }) async {
    final data = await _client.get('/search', queryParams: {
      'q': q,
      'filter': filter,
      'limit': limit,
    });
    return SearchResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches metadata for a single track by [videoId].
  Future<Track> getTrack(String videoId) async {
    final data = await _client.get('/track/$videoId');
    return Track.fromJson(data as Map<String, dynamic>);
  }

  /// Requests a short-lived streaming URL ticket for [videoId].
  Future<AudioTicket> getAudioTicket(String videoId) async {
    final data = await _client.post('/audio/$videoId/ticket', null);
    return AudioTicket.fromJson(data as Map<String, dynamic>);
  }
}
