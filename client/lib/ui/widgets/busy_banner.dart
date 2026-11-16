import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class BusyBanner extends StatefulWidget {
  const BusyBanner({
    super.key,
    required this.retryAfterSeconds,
    this.onRetry,
  });

  final int retryAfterSeconds;
  final VoidCallback? onRetry;

  @override
  State<BusyBanner> createState() => _BusyBannerState();
}

class _BusyBannerState extends State<BusyBanner> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.retryAfterSeconds > 0 ? widget.retryAfterSeconds : 5;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
        widget.onRetry?.call();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MelodiaTokens.spacingLg,
        vertical: MelodiaTokens.spacingSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MelodiaTokens.spacingLg,
        vertical: MelodiaTokens.spacingMd,
      ),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
        border: Border.all(color: tokens.separator),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: tokens.accent, size: 20),
          const SizedBox(width: MelodiaTokens.spacingMd),
          Expanded(
            child: Text(
              _remaining > 0
                  ? 'The music service is busy right now. Retrying in ${_remaining}s...'
                  : 'Retrying now...',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
          if (_remaining == 0 && widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              child: Text(
                'Retry',
                style: MelodiaTokens.subhead.copyWith(color: tokens.accent),
              ),
            ),
        ],
      ),
    );
  }
}
