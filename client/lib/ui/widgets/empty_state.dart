import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Semantics(
      label: '$title. ${subtitle ?? ""}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MelodiaTokens.spacingXxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: tokens.textTertiary,
              ),
              const SizedBox(height: MelodiaTokens.spacingLg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MelodiaTokens.title3.copyWith(color: tokens.text),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: MelodiaTokens.spacingSm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: MelodiaTokens.subhead.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: MelodiaTokens.spacingLg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

