/// Short-lived audio URL ticket caching service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/music_api.dart';
import '../core/config.dart' as config;

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final audioUrlServiceProvider = Provider<AudioUrlService>((ref) {
  return AudioUrlService(ref.watch(musicApiProvider));
});

// ---------------------------------------------------------------------------
// Cache entry
// ---------------------------------------------------------------------------

typedef _CacheEntry = ({String url, DateTime expiry});

// ---------------------------------------------------------------------------
// AudioUrlService
// ---------------------------------------------------------------------------

/// Fetches and caches audio stream URLs from the backend ticket endpoint.
///
/// A cached ticket is considered stale when it expires within [_staleness],
/// so we always have a fresh URL ready before the stream starts.
class AudioUrlService {
  AudioUrlService(this._musicApi);

  final MusicApi _musicApi;

  static const Duration _staleness = Duration(minutes: 5);

  final Map<String, _CacheEntry> _cache = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the absolute streaming URL for [videoId].
  ///
  /// Uses a cached ticket if still valid (more than [_staleness] from expiry).
  /// Otherwise fetches a fresh ticket from the backend.
  Future<String> urlFor(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null &&
        cached.expiry.isAfter(DateTime.now().add(_staleness))) {
      return cached.url;
    }

    final ticket = await _musicApi.getAudioTicket(videoId);
    return _store(videoId, ticket);
  }

  /// Clears the cached ticket for [videoId], forcing the next [urlFor] call
  /// to fetch a fresh one.
  void invalidate(String videoId) {
    _cache.remove(videoId);
  }

  /// Clears all cached tickets.
  void invalidateAll() {
    _cache.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String _store(String videoId, AudioTicket ticket) {
    final expiry =
        DateTime.now().add(Duration(seconds: ticket.expiresIn));
    final absoluteUrl = config.apiUrl + ticket.url;
    _cache[videoId] = (url: absoluteUrl, expiry: expiry);
    return absoluteUrl;
  }
}
