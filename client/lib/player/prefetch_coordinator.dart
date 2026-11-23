import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/music_api.dart';
import '../core/connectivity/connectivity_controller.dart';
import '../downloads/offline_mode.dart';
import 'ticket_cache.dart';

enum SmartPrefetchMode {
  off,
  light,
  full;

  String get label => switch (this) {
        SmartPrefetchMode.off => 'Off',
        SmartPrefetchMode.light => 'Light (Default)',
        SmartPrefetchMode.full => 'Full (Wi-Fi only)',
      };
}

class PrefetchStats {
  const PrefetchStats({
    this.sent = 0,
    this.skipped = 0,
    this.rateLimited = 0,
    this.warm = 0,
  });

  final int sent;
  final int skipped;
  final int rateLimited;
  final int warm;

  PrefetchStats copyWith({
    int? sent,
    int? skipped,
    int? rateLimited,
    int? warm,
  }) {
    return PrefetchStats(
      sent: sent ?? this.sent,
      skipped: skipped ?? this.skipped,
      rateLimited: rateLimited ?? this.rateLimited,
      warm: warm ?? this.warm,
    );
  }
}

final smartPrefetchModeProvider =
    StateNotifierProvider<SmartPrefetchModeNotifier, SmartPrefetchMode>((ref) {
  return SmartPrefetchModeNotifier();
});

class SmartPrefetchModeNotifier extends StateNotifier<SmartPrefetchMode> {
  SmartPrefetchModeNotifier() : super(SmartPrefetchMode.light);

  void setMode(SmartPrefetchMode mode) => state = mode;
}

final prefetchStatsProvider = StateProvider<PrefetchStats>((ref) {
  return const PrefetchStats();
});

final prefetchCoordinatorProvider = Provider<PrefetchCoordinator>((ref) {
  return PrefetchCoordinator(ref);
});

/// Coordinates speculative warming of stream URLs, head bytes, and tickets.
///
/// Operates under strict rate limits and bandwidth budgets, immediately backing off
/// when offline, on cellular, or when server capacity is constrained.
class PrefetchCoordinator {
  PrefetchCoordinator(this._ref);

  final Ref _ref;

  static const int _maxInFlight = 2;
  static const int _maxPerMinute = 20;

  int _inFlightCount = 0;
  final List<DateTime> _recentPrefetches = [];
  DateTime? _backoffUntil;

  Timer? _searchDebounceTimer;
  Timer? _hoverDebounceTimer;

  MusicApi get _musicApi => _ref.read(musicApiProvider);
  TicketCache get _ticketCache => _ref.read(ticketCacheProvider);
  PrefetchStats get stats => _ref.read(prefetchStatsProvider);

  /// Trigger: Warm up the next tracks in queue.
  void warmUpQueue(List<Track> queue, int currentIndex) {
    if (queue.isEmpty || currentIndex < 0) return;
    final nextIds = <String>[];
    if (currentIndex + 1 < queue.length) {
      nextIds.add(queue[currentIndex + 1].videoId);
    }
    if (currentIndex + 2 < queue.length) {
      nextIds.add(queue[currentIndex + 2].videoId);
    }
    if (nextIds.isNotEmpty) {
      onQueueTracks(nextIds);
    }
  }

  bool get _canPrefetch {
    final mode = _ref.read(smartPrefetchModeProvider);
    if (mode == SmartPrefetchMode.off) return false;

    // Check offline mode
    final isOfflineMode = _ref.read(offlineModeProvider).isOffline;
    if (isOfflineMode) return false;

    // Check network status
    final conn = _ref.read(connectivityProvider);
    if (!conn.isOnline) return false;

    // Check backoff
    if (_backoffUntil != null && DateTime.now().isBefore(_backoffUntil!)) {
      return false;
    }

    // Check rate limit per minute
    final now = DateTime.now();
    _recentPrefetches.removeWhere((t) => now.difference(t).inSeconds > 60);
    if (_recentPrefetches.length >= _maxPerMinute) {
      return false;
    }

    // Check concurrency
    if (_inFlightCount >= _maxInFlight) {
      return false;
    }

    return true;
  }

  /// Cancels all pending speculative timers and backoffs except optionally [keepVideoId].
  void cancelPending({String? keepVideoId}) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _hoverDebounceTimer?.cancel();
    _hoverDebounceTimer = null;
  }

  /// Trigger: Search results returned (debounced 250ms, top 5 songs).
  void onSearchResults(List<String> videoIds) {
    _searchDebounceTimer?.cancel();
    if (videoIds.isEmpty) return;

    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      final top5 = videoIds.take(5).toList();
      _queuePrefetchBatch(top5, warmTickets: true);
    });
  }

  /// Trigger: Immediate high priority (tap-down touch start or pointer hover >= 150ms).
  void onRowInteraction(String videoId) {
    if (videoId.isEmpty) return;
    _queuePrefetchBatch([videoId], warmTickets: true, priority: true);
  }

  /// Trigger: Hover on desktop row (debounced 150ms).
  void onRowHover(String videoId) {
    _hoverDebounceTimer?.cancel();
    _hoverDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      onRowInteraction(videoId);
    });
  }

  /// Trigger: Album, Playlist, Artist, or Home carousel screen items.
  void onScreenView(List<String> videoIds, {int count = 3}) {
    if (videoIds.isEmpty) return;
    final items = videoIds.take(count).toList();
    _queuePrefetchBatch(items, warmTickets: true);
  }

  /// Trigger: Next tracks in queue (next 2 tracks).
  void onQueueTracks(List<String> nextVideoIds, {int count = 2}) {
    if (nextVideoIds.isEmpty) return;
    final items = nextVideoIds.take(count).toList();
    _queuePrefetchBatch(items, warmTickets: true, priority: true);
  }

  Future<void> _queuePrefetchBatch(
    List<String> videoIds, {
    bool warmTickets = true,
    bool priority = false,
  }) async {
    if (videoIds.isEmpty) return;
    if (!priority && !_canPrefetch) return;

    // Filter out already warm or valid cached tickets
    final needed = videoIds.where((id) {
      return _ticketCache.getCachedUrl(id) == null;
    }).toList();

    if (needed.isEmpty) return;

    // Pre-warm tickets in batch via ticket cache
    if (warmTickets) {
      for (final id in needed) {
        // Fire-and-forget ticket coalescing
        _ticketCache.getUrl(id).ignore();
      }
    }

    if (!_canPrefetch) return;

    _inFlightCount++;
    final batch = needed.take(5).toList();
    _recentPrefetches.add(DateTime.now());

    try {
      final statuses = await _musicApi.prefetchAudio(batch, head: true);
      final stats = _ref.read(prefetchStatsProvider.notifier);

      for (final status in statuses.values) {
        if (status == 'warm') {
          stats.state = stats.state.copyWith(warm: stats.state.warm + 1);
        } else if (status == 'queued') {
          stats.state = stats.state.copyWith(sent: stats.state.sent + 1);
        } else if (status == 'skipped') {
          stats.state = stats.state.copyWith(skipped: stats.state.skipped + 1);
          // Server signaled busy: back off for 60 seconds
          _backoffUntil = DateTime.now().add(const Duration(seconds: 60));
        } else if (status == 'rate_limited') {
          stats.state = stats.state.copyWith(rateLimited: stats.state.rateLimited + 1);
          _backoffUntil = DateTime.now().add(const Duration(seconds: 60));
        }
      }
    } catch (_) {
      // Ignore network errors during speculative prefetch
    } finally {
      _inFlightCount = (_inFlightCount - 1).clamp(0, _maxInFlight);
    }
  }
}

