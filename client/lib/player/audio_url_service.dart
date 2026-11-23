/// Short-lived audio URL ticket caching service delegating to [TicketCache].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ticket_cache.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final audioUrlServiceProvider = Provider<AudioUrlService>((ref) {
  return AudioUrlService(ref.watch(ticketCacheProvider));
});

// ---------------------------------------------------------------------------
// AudioUrlService
// ---------------------------------------------------------------------------

/// High-level facade for obtaining streaming URLs backed by [TicketCache].
class AudioUrlService {
  AudioUrlService(this._ticketCache);

  final TicketCache _ticketCache;

  /// Returns the absolute streaming URL for [videoId].
  Future<String> urlFor(String videoId) => _ticketCache.getUrl(videoId);

  /// Synchronously returns the cached URL if still valid, or null.
  String? getCachedUrl(String videoId) => _ticketCache.getCachedUrl(videoId);

  /// Clears the cached ticket for [videoId].
  void invalidate(String videoId) => _ticketCache.invalidate(videoId);

  /// Clears all cached tickets.
  void invalidateAll() => _ticketCache.invalidateAll();
}
