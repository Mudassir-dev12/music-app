import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class VolumeSlider extends StatelessWidget {
  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onChanged,
  });

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    final IconData icon = volume == 0
        ? Icons.volume_off_rounded
        : (volume < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded);

    return Semantics(
      label: 'Volume ${(volume * 100).toInt()}%',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: tokens.textSecondary,
          ),
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: tokens.text,
                inactiveTrackColor: tokens.surface2,
                thumbColor: tokens.text,
                overlayColor: tokens.transparent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
              ),
              child: Slider(
                value: volume.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

