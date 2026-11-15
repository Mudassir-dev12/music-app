import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Semantics(
      label: 'Error: $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MelodiaTokens.spacingXxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: tokens.destructive,
              ),
              const SizedBox(height: MelodiaTokens.spacingMd),
              Text(
                message,
                textAlign: TextAlign.center,
                style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: MelodiaTokens.spacingLg),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.surface2,
                  foregroundColor: tokens.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: MelodiaTokens.headline.copyWith(color: tokens.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
