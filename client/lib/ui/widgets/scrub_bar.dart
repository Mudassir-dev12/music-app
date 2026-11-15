import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class ScrubBar extends StatefulWidget {
  const ScrubBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(Duration pos, Duration dur) {
    final remaining = dur - pos;
    if (remaining < Duration.zero) return '-0:00';
    return '-${_formatDuration(remaining)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    final totalMs = widget.duration.inMilliseconds.toDouble();
    final posMs = widget.position.inMilliseconds.toDouble();
    final effectiveProgress = totalMs > 0
        ? (_isDragging ? _dragValue : (posMs / totalMs)).clamp(0.0, 1.0)
        : 0.0;

    final currentPos = totalMs > 0
        ? Duration(milliseconds: (effectiveProgress * totalMs).round())
        : Duration.zero;

    return Semantics(
      label: 'Progress bar: ${_formatDuration(currentPos)} of ${_formatDuration(widget.duration)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: _isDragging ? 8.0 : 4.0,
              activeTrackColor: tokens.text,
              inactiveTrackColor: tokens.surface2,
              thumbColor: tokens.text,
              overlayColor: tokens.transparent,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: _isDragging ? 8.0 : 5.0,
              ),
            ),
            child: Slider(
              value: effectiveProgress,
              onChangeStart: (_) {
                setState(() {
                  _isDragging = true;
                  _dragValue = effectiveProgress;
                });
              },
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                setState(() {
                  _isDragging = false;
                });
                final targetMs = (val * totalMs).round();
                widget.onSeek(Duration(milliseconds: targetMs));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(currentPos),
                  style: MelodiaTokens.caption.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                Text(
                  _formatRemaining(currentPos, widget.duration),
                  style: MelodiaTokens.caption.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
