import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlaybackPath {
  downloaded,
  cacheFull,
  cachePartial,
  warm,
  cold,
}

extension PlaybackPathExtension on PlaybackPath {
  String get label {
    switch (this) {
      case PlaybackPath.downloaded:
        return 'Downloaded';
      case PlaybackPath.cacheFull:
        return 'Cache (Full)';
      case PlaybackPath.cachePartial:
        return 'Cache (Partial)';
      case PlaybackPath.warm:
        return 'Warm Stream';
      case PlaybackPath.cold:
        return 'Cold Stream';
    }
  }
}

class PlaybackMetricEntry {
  final String videoId;
  final Duration timeToFirstAudio;
  final PlaybackPath path;
  final int stalls;
  final DateTime timestamp;

  const PlaybackMetricEntry({
    required this.videoId,
    required this.timeToFirstAudio,
    required this.path,
    this.stalls = 0,
    required this.timestamp,
  });
}

class PlaybackMetrics {
  static const int maxEntries = 100;
  final List<PlaybackMetricEntry> _entries = [];

  void record({
    required String videoId,
    required Duration timeToFirstAudio,
    required PlaybackPath path,
    int stalls = 0,
  }) {
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(PlaybackMetricEntry(
      videoId: videoId,
      timeToFirstAudio: timeToFirstAudio,
      path: path,
      stalls: stalls,
      timestamp: DateTime.now(),
    ));
  }

  List<PlaybackMetricEntry> get entries => List.unmodifiable(_entries);

  double get p50LatencyMs {
    if (_entries.isEmpty) return 0.0;
    final lats = _entries.map((e) => e.timeToFirstAudio.inMilliseconds).toList()..sort();
    final mid = lats.length ~/ 2;
    return lats[mid].toDouble();
  }

  double get p95LatencyMs {
    if (_entries.isEmpty) return 0.0;
    final lats = _entries.map((e) => e.timeToFirstAudio.inMilliseconds).toList()..sort();
    final idx = (lats.length * 0.95).floor().clamp(0, lats.length - 1);
    return lats[idx].toDouble();
  }

  int get count => _entries.length;

  int countForPath(PlaybackPath p) => _entries.where((e) => e.path == p).length;

  void clear() {
    _entries.clear();
  }
}

final playbackMetricsProvider = Provider<PlaybackMetrics>((ref) => PlaybackMetrics());

