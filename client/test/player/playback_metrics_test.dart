import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/player/playback_metrics.dart';

void main() {
  group('PlaybackMetrics', () {
    late PlaybackMetrics metrics;

    setUp(() {
      metrics = PlaybackMetrics();
    });

    test('initializes empty with 0 p50 and p95', () {
      expect(metrics.count, equals(0));
      expect(metrics.p50LatencyMs, equals(0.0));
      expect(metrics.p95LatencyMs, equals(0.0));
      expect(metrics.entries, isEmpty);
    });

    test('records entries and calculates p50 and p95 correctly', () {
      // Record 10 entries with latencies 100ms, 200ms, ..., 1000ms
      for (int i = 1; i <= 10; i++) {
        metrics.record(
          videoId: 'vid$i',
          timeToFirstAudio: Duration(milliseconds: i * 100),
          path: i.isEven ? PlaybackPath.warm : PlaybackPath.cold,
        );
      }

      expect(metrics.count, equals(10));
      expect(metrics.countForPath(PlaybackPath.warm), equals(5));
      expect(metrics.countForPath(PlaybackPath.cold), equals(5));

      // Sorted latencies: 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000
      // mid = 10 ~/ 2 = 5 -> lats[5] = 600ms
      expect(metrics.p50LatencyMs, equals(600.0));
      // p95 = index (10 * 0.95).floor() = 9 -> lats[9] = 1000ms
      expect(metrics.p95LatencyMs, equals(1000.0));
    });

    test('ring buffer caps at 100 entries and drops oldest', () {
      for (int i = 0; i < 120; i++) {
        metrics.record(
          videoId: 'vid$i',
          timeToFirstAudio: Duration(milliseconds: i),
          path: PlaybackPath.cacheFull,
        );
      }

      expect(metrics.count, equals(100));
      // Oldest entry should be vid20
      expect(metrics.entries.first.videoId, equals('vid20'));
      expect(metrics.entries.last.videoId, equals('vid119'));
    });

    test('clear resets entries', () {
      metrics.record(
        videoId: 'vid1',
        timeToFirstAudio: const Duration(milliseconds: 250),
        path: PlaybackPath.downloaded,
      );
      expect(metrics.count, equals(1));

      metrics.clear();
      expect(metrics.count, equals(0));
      expect(metrics.entries, isEmpty);
    });
  });
}

