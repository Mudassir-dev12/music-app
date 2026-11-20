import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../../voice/voice_controller.dart';
import 'mic_status_indicator.dart';
import 'voice_help_sheet.dart';

class VoiceOverlay extends ConsumerWidget {
  const VoiceOverlay({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const VoiceOverlay(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final voiceState = ref.watch(voiceControllerProvider);
    final voiceCtrl = ref.read(voiceControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MelodiaTokens.spacingLg,
        vertical: MelodiaTokens.spacingLg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: MelodiaTokens.spacingMd),

            // Top Header: Title, Status, and Help Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const MicStatusIndicator(size: 10, showLabel: true),
                    const SizedBox(width: MelodiaTokens.spacingSm),
                    if (voiceState.isEarbudsConnected)
                      Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: tokens.surface2,
                        avatar: Icon(Icons.headphones, size: 14, color: tokens.accent),
                        label: Text(
                          'Earbuds',
                          style: MelodiaTokens.caption.copyWith(color: tokens.accent),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.help_outline, color: tokens.textSecondary),
                  tooltip: 'Voice commands help',
                  onPressed: () => VoiceHelpSheet.show(context),
                ),
              ],
            ),
            const SizedBox(height: MelodiaTokens.spacingLg),

            // Pulsing Mic Circle
            GestureDetector(
              onTap: () {
                if (voiceState.isListening) {
                  voiceCtrl.stopListening();
                } else {
                  voiceCtrl.startListening();
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // ignore: deprecated_member_use
                  color: voiceState.isListening ? tokens.accent.withOpacity(0.2) : tokens.surface2,
                  border: Border.all(
                    color: voiceState.isListening
                        ? tokens.accent
                        : tokens.separator,
                    width: 2,
                  ),
                ),
                child: Icon(
                  voiceState.isListening ? Icons.mic : Icons.mic_none,
                  size: 38,
                  color: voiceState.isListening
                      ? tokens.accent
                      : tokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: MelodiaTokens.spacingLg),

            // Transcript / Status Text
            Text(
              voiceState.lastTranscript?.isNotEmpty == true
                  ? '"${voiceState.lastTranscript}"'
                  : (voiceState.isListening ? 'Listening...' : 'Tap mic to speak'),
              style: MelodiaTokens.headline.copyWith(
                color: voiceState.isListening ? tokens.text : tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MelodiaTokens.spacingSm),

            // Spoken Reply or Feedback
            if (voiceState.lastReply != null)
              Text(
                voiceState.lastReply!,
                style: MelodiaTokens.subhead.copyWith(color: tokens.accent),
                textAlign: TextAlign.center,
              ),

            // Disambiguation Prompt if 2 candidates
            if (voiceState.disambiguationCandidates != null &&
                voiceState.disambiguationCandidates!.isNotEmpty) ...[
              const SizedBox(height: MelodiaTokens.spacingMd),
              Container(
                padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(12),
                  // ignore: deprecated_member_use
                  border: Border.all(color: tokens.accent.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Which song did you mean?',
                      style: MelodiaTokens.headline.copyWith(color: tokens.text),
                    ),
                    const SizedBox(height: MelodiaTokens.spacingSm),
                    ...voiceState.disambiguationCandidates!.take(2).toList().asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final track = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(top: MelodiaTokens.spacingXs),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            ref.read(playerControllerProvider.notifier).playTrack(track);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            '$idx. ${track.title} - ${track.artist}',
                            style: MelodiaTokens.callout.copyWith(color: tokens.text),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: MelodiaTokens.spacingLg),

            // Quick Example Chips
            Wrap(
              spacing: MelodiaTokens.spacingSm,
              runSpacing: MelodiaTokens.spacingXs,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickChip(tokens, 'Liked songs', () {
                  voiceCtrl.startListening();
                }),
                _buildQuickChip(tokens, 'Volume 50%', () {
                  voiceCtrl.startListening();
                }),
                _buildQuickChip(tokens, 'Stop in 20 min', () {
                  voiceCtrl.startListening();
                }),
                _buildQuickChip(tokens, 'Next', () {
                  voiceCtrl.startListening();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(MelodiaTokens tokens, String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: tokens.surface2,
      side: BorderSide(color: tokens.separator),
      label: Text(
        label,
        style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
      ),
      onPressed: onTap,
    );
  }
}
