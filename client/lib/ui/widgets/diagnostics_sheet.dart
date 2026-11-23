import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/audio_cache_provider.dart';
import '../../player/playback_metrics.dart';
import '../../player/prefetch_coordinator.dart';
import '../../theme/tokens.dart';

class DiagnosticsSheet extends ConsumerWidget {
  const DiagnosticsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const DiagnosticsSheet(),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1000) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final metrics = ref.watch(playbackMetricsProvider);
    final coordinator = ref.watch(prefetchCoordinatorProvider);
    final audioCache = ref.watch(audioCacheProvider);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MelodiaTokens.radiusSheet),
        ),
      ),
      padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: MelodiaTokens.spacingMd),
                decoration: BoxDecoration(
                  color: tokens.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playback Diagnostics',
                  style: MelodiaTokens.title3.copyWith(color: tokens.text),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),
            _buildStatGroup(
              tokens,
              'LATENCY & HIT RATE',
              [
                _buildRow(tokens, 'p50 Time-to-First-Audio', '${metrics.p50LatencyMs.toStringAsFixed(0)} ms'),
                _buildRow(tokens, 'p95 Time-to-First-Audio', '${metrics.p95LatencyMs.toStringAsFixed(0)} ms'),
                _buildRow(tokens, 'Recorded Plays', '${metrics.count} / 100'),
              ],
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),
            _buildStatGroup(
              tokens,
              'PATH BREAKDOWN',
              [
                _buildRow(tokens, 'Downloaded', '${metrics.countForPath(PlaybackPath.downloaded)}'),
                _buildRow(tokens, 'Cache (Full)', '${metrics.countForPath(PlaybackPath.cacheFull)}'),
                _buildRow(tokens, 'Warm Stream', '${metrics.countForPath(PlaybackPath.warm)}'),
                _buildRow(tokens, 'Cold Stream', '${metrics.countForPath(PlaybackPath.cold)}'),
              ],
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),
            _buildStatGroup(
              tokens,
              'PREFETCH COORDINATOR',
              [
                _buildRow(tokens, 'Requests Sent', '${coordinator.stats.sent}'),
                _buildRow(tokens, 'Warm Hits', '${coordinator.stats.warm}'),
                _buildRow(tokens, 'Skipped (Budget/Offline)', '${coordinator.stats.skipped}'),
                _buildRow(tokens, 'Rate Limited (429)', '${coordinator.stats.rateLimited}'),
              ],
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),
            FutureBuilder<List<int>>(
              future: Future.wait([audioCache.totalBytesUsed(), audioCache.getCapBytes()]),
              builder: (context, snapshot) {
                final used = snapshot.data != null ? snapshot.data![0] : 0;
                final cap = snapshot.data != null ? snapshot.data![1] : 500 * 1024 * 1024;
                return _buildStatGroup(
                  tokens,
                  'AUDIO CACHE',
                  [
                    _buildRow(tokens, 'Used / Cap', '${_formatBytes(used)} / ${_formatBytes(cap)}'),
                    _buildRow(tokens, 'Platform Support', audioCache.isSupported ? 'Native (Supported)' : 'Web Stub'),
                  ],
                );
              },
            ),
            const SizedBox(height: MelodiaTokens.spacingLg),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGroup(MelodiaTokens tokens, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MelodiaTokens.caption.copyWith(
              color: tokens.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingSm),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(MelodiaTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
          ),
          Text(
            value,
            style: MelodiaTokens.subhead.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
