import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/music_api.dart';
import '../core/config.dart' as config;

class CachedTicket {
  const CachedTicket({
    required this.videoId,
    required this.url,
    required this.expiry,
  });

  final String videoId;
  final String url;
  final DateTime expiry;

  /// A ticket is considered expired when it is within 60s of its actual expiry.
  bool get isExpired =>
      DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)));
}

final ticketCacheProvider = Provider<TicketCache>((ref) {
  return TicketCache(ref.watch(musicApiProvider));
});

/// High-performance in-memory ticket cache with 30ms batch coalescing.
///
/// Reduces backend round trips by bundling up to 10 ticket requests into a single
/// `POST /audio/tickets` call. Tickets are never written to disk or logged.
class TicketCache {
  TicketCache(this._musicApi);

  final MusicApi _musicApi;
  final Map<String, CachedTicket> _cache = {};

  final Map<String, List<Completer<String>>> _pendingRequests = {};
  Timer? _batchTimer;

  static const Duration _coalesceWindow = Duration(milliseconds: 30);
  static const int _maxBatchSize = 10;

  /// Returns the streaming URL for [videoId], either from memory or by fetching.
  Future<String> getUrl(String videoId, {String purpose = 'stream'}) async {
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Coalesce request into pending batch
    final completer = Completer<String>();
    _pendingRequests.putIfAbsent(videoId, () => []).add(completer);

    if (_pendingRequests.length >= _maxBatchSize) {
      _flushBatch(purpose);
    } else {
      _batchTimer ??= Timer(_coalesceWindow, () => _flushBatch(purpose));
    }

    return completer.future;
  }

  /// Synchronously returns cached URL if still valid, or null if missing/expired.
  String? getCachedUrl(String videoId) {
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }
    return null;
  }

  /// Manually inserts or updates a ticket in memory (e.g. from prefetch).
  void put(String videoId, AudioTicket ticket) {
    final expiry = DateTime.now().add(Duration(seconds: ticket.expiresIn));
    final absoluteUrl = config.apiUrl + ticket.url;
    _cache[videoId] = CachedTicket(
      videoId: videoId,
      url: absoluteUrl,
      expiry: expiry,
    );
  }

  /// Removes a cached ticket (e.g. on 401 or stream failure).
  void invalidate(String videoId) {
    _cache.remove(videoId);
  }

  /// Clears all cached tickets.
  void invalidateAll() {
    _cache.clear();
  }

  void _flushBatch(String purpose) {
    _batchTimer?.cancel();
    _batchTimer = null;

    if (_pendingRequests.isEmpty) return;

    final batchToProcess = Map<String, List<Completer<String>>>.from(
      _pendingRequests,
    );
    _pendingRequests.clear();

    final videoIds = batchToProcess.keys.toList();

    _executeBatch(videoIds, batchToProcess, purpose);
  }

  Future<void> _executeBatch(
    List<String> videoIds,
    Map<String, List<Completer<String>>> waiters,
    String purpose,
  ) async {
    // If only 1 id, or if batch fails, we can fallback gracefully
    if (videoIds.length == 1) {
      final vid = videoIds.first;
      try {
        final ticket = await _musicApi.getAudioTicket(vid, purpose: purpose);
        put(vid, ticket);
        final url = _cache[vid]!.url;
        for (final c in waiters[vid] ?? <Completer<String>>[]) {
          if (!c.isCompleted) c.complete(url);
        }
      } catch (err, st) {
        for (final c in waiters[vid] ?? <Completer<String>>[]) {
          if (!c.isCompleted) c.completeError(err, st);
        }
      }
      return;
    }

    try {
      final resultMap = await _musicApi.getAudioTicketsBatch(
        videoIds,
        purpose: purpose,
      );
      for (final vid in videoIds) {
        final ticket = resultMap[vid];
        if (ticket != null) {
          put(vid, ticket);
          final url = _cache[vid]!.url;
          for (final c in waiters[vid] ?? <Completer<String>>[]) {
            if (!c.isCompleted) c.complete(url);
          }
        } else {
          // Fallback to single ticket call on demand
          _fallbackSingle(vid, waiters[vid] ?? [], purpose);
        }
      }
    } catch (_) {
      // If batch endpoint failed entirely, fallback each id individually
      for (final vid in videoIds) {
        _fallbackSingle(vid, waiters[vid] ?? [], purpose);
      }
    }
  }

  Future<void> _fallbackSingle(
    String vid,
    List<Completer<String>> completers,
    String purpose,
  ) async {
    try {
      final ticket = await _musicApi.getAudioTicket(vid, purpose: purpose);
      put(vid, ticket);
      final url = _cache[vid]!.url;
      for (final c in completers) {
        if (!c.isCompleted) c.complete(url);
      }
    } catch (err, st) {
      for (final c in completers) {
        if (!c.isCompleted) c.completeError(err, st);
      }
    }
  }
}
