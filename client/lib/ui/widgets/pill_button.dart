import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: tokens.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: tokens.accent,
                  size: 20,
                ),
                const SizedBox(width: MelodiaTokens.spacingSm),
                Text(
                  label,
                  style: MelodiaTokens.headline.copyWith(
                    color: tokens.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
