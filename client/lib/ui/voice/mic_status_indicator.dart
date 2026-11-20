import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../voice/voice_controller.dart';

class MicStatusIndicator extends ConsumerWidget {
  const MicStatusIndicator({
    super.key,
    this.size = 12.0,
    this.showLabel = false,
  });

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final voiceState = ref.watch(voiceControllerProvider);

    final (color, label) = switch (voiceState.status) {
      VoiceStatus.listening => (tokens.statusOnline, 'Listening'),
      VoiceStatus.armed => (tokens.statusOnline, 'Ready'),
      VoiceStatus.restarting => (tokens.accent, 'Listening...'),
      VoiceStatus.processing => (tokens.accent, 'Processing'),
      VoiceStatus.confirming => (tokens.statusWarning, 'Waiting choice'),
      VoiceStatus.executing => (tokens.accent, 'Executing'),
      VoiceStatus.speaking => (tokens.accent, 'Speaking'),
      VoiceStatus.needsPermission => (tokens.statusWarning, 'Permission needed'),
      VoiceStatus.error => (tokens.destructive, 'Error'),
      VoiceStatus.paused => (tokens.textSecondary, 'Paused'),
      VoiceStatus.idle => (tokens.textTertiary, 'Off'),
    };

    final isPulsing = voiceState.status == VoiceStatus.listening ||
        voiceState.status == VoiceStatus.speaking;

    Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isPulsing
            ? [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: color.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );

    if (!showLabel) return dot;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: MelodiaTokens.spacingSm),
        Text(
          label,
          style: MelodiaTokens.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
