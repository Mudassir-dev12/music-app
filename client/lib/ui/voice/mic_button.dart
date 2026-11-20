import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../voice/voice_controller.dart';
import 'voice_overlay.dart';

class MicButton extends ConsumerWidget {
  const MicButton({
    super.key,
    this.iconSize = 24.0,
    this.color,
  });

  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final voiceState = ref.watch(voiceControllerProvider);
    final isListening = voiceState.isListening;

    final effectiveColor = isListening
        ? tokens.accent
        : (color ?? tokens.textSecondary);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          iconSize: iconSize,
          icon: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: effectiveColor,
          ),
          tooltip: 'Voice control (V)',
          onPressed: () {
            ref.read(voiceControllerProvider.notifier).startListening();
            VoiceOverlay.show(context);
          },
        ),
        if (isListening)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tokens.statusOnline,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: tokens.statusOnline.withOpacity(0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
