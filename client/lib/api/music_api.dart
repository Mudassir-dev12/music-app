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

  /// Requests a short-lived streaming or download URL ticket for [videoId].
  Future<AudioTicket> getAudioTicket(String videoId, {String purpose = 'stream'}) async {
    final body = purpose == 'stream' ? null : {'purpose': purpose};
    final data = await _client.post('/audio/$videoId/ticket', body);
    return AudioTicket.fromJson(data as Map<String, dynamic>);
  }

  /// Requests short-lived streaming or download tickets in batch for [videoIds] (up to 10).
  Future<Map<String, AudioTicket>> getAudioTicketsBatch(
    List<String> videoIds, {
    String purpose = 'stream',
  }) async {
    if (videoIds.isEmpty) return {};
    final data = await _client.post('/audio/tickets', {
      'video_ids': videoIds,
      'purpose': purpose,
    });
    if (data is! Map<String, dynamic>) return {};
    return data.map(
      (k, v) => MapEntry(k, AudioTicket.fromJson(v as Map<String, dynamic>)),
    );
  }

  /// Requests background prefetching for [videoIds] (up to 5).
  Future<Map<String, String>> prefetchAudio(
    List<String> videoIds, {
    bool head = true,
  }) async {
    if (videoIds.isEmpty) return {};
    final data = await _client.post('/audio/prefetch', {
      'video_ids': videoIds,
      'head': head,
    });
    if (data is Map<String, dynamic> && data['statuses'] is Map<String, dynamic>) {
      return (data['statuses'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v.toString()),
      );
    }
    return {};
  }
}
