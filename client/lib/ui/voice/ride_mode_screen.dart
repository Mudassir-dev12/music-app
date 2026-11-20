import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_controller.dart';
import '../../theme/tokens.dart';
import '../../voice/voice_controller.dart';
import 'mic_status_indicator.dart';
import 'voice_help_sheet.dart';

class RideModeScreen extends ConsumerStatefulWidget {
  const RideModeScreen({super.key});

  static const routeName = '/ride-mode';

  @override
  ConsumerState<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends ConsumerState<RideModeScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-start continuous hands-free listening in Ride Mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceControllerProvider.notifier).startListening(rideMode: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playerState = ref.watch(playerControllerProvider);
    final voiceState = ref.watch(voiceControllerProvider);
    final playerCtrl = ref.read(playerControllerProvider.notifier);
    final voiceCtrl = ref.read(voiceControllerProvider.notifier);

    final currentTrack = playerState.queue.currentTrack;
    final isPlaying = playerState.isPlaying;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingMd,
          ),
          child: Column(
            children: [
              // 1. Top Header: Exit, Earbuds status, Help
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MelodiaTokens.spacingMd,
                        vertical: MelodiaTokens.spacingSm,
                      ),
                    ),
                    icon: const Icon(Icons.close),
                    label: Text(
                      'Exit',
                      style: MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),

                  // Route status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingMd,
                      vertical: MelodiaTokens.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: voiceState.isEarbudsConnected
                            ? tokens.statusOnline
                            : tokens.separator,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          voiceState.isEarbudsConnected
                              ? Icons.headphones
                              : Icons.volume_down,
                          size: 16,
                          color: voiceState.isEarbudsConnected
                              ? tokens.statusOnline
                              : tokens.textSecondary,
                        ),
                        const SizedBox(width: MelodiaTokens.spacingXs),
                        Text(
                          voiceState.isEarbudsConnected ? 'Earbuds' : 'Speaker',
                          style: MelodiaTokens.caption.copyWith(
                            color: voiceState.isEarbudsConnected
                                ? tokens.statusOnline
                                : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: Icon(Icons.help_outline, color: tokens.textSecondary),
                    tooltip: 'Commands Help',
                    onPressed: () => VoiceHelpSheet.show(context),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // 2. Center: Listening Status & Transcript
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: MelodiaTokens.spacingLg,
                  vertical: MelodiaTokens.spacingXl,
                ),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: voiceState.isListening
                        // ignore: deprecated_member_use
                        ? tokens.statusOnline.withOpacity(0.5)
                        : tokens.separator,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MicStatusIndicator(size: 14),
                        const SizedBox(width: MelodiaTokens.spacingSm),
                        Text(
                          voiceState.isListening
                              ? 'Hands-free Listening'
                              : 'Listening Paused',
                          style: MelodiaTokens.headline.copyWith(
                            color: voiceState.isListening
                                ? tokens.statusOnline
                                : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MelodiaTokens.spacingMd),
                    Text(
                      voiceState.lastTranscript?.isNotEmpty == true
                          ? '"${voiceState.lastTranscript}"'
                          : 'Say "play music", "next song", "volume low"',
                      style: MelodiaTokens.title3.copyWith(
                        color: voiceState.lastTranscript?.isNotEmpty == true
                            ? tokens.text
                            : tokens.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (voiceState.lastReply != null) ...[
                      const SizedBox(height: MelodiaTokens.spacingSm),
                      Text(
                        voiceState.lastReply!,
                        style: MelodiaTokens.callout.copyWith(color: tokens.accent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // 3. Giant Current Song Info
              if (currentTrack != null) ...[
                Text(
                  currentTrack.title,
                  style: MelodiaTokens.title1.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MelodiaTokens.spacingSm),
                Text(
                  currentTrack.artist,
                  style: MelodiaTokens.title3.copyWith(color: tokens.textSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Text(
                  'No Song Playing',
                  style: MelodiaTokens.title1.copyWith(color: tokens.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MelodiaTokens.spacingSm),
                Text(
                  'Say "play my liked songs" or "play music"',
                  style: MelodiaTokens.callout.copyWith(color: tokens.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(flex: 1),

              // 4. Giant High-Contrast Touch Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Previous
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: tokens.surface2,
                        foregroundColor: tokens.text,
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        playerCtrl.skipPrevious();
                      },
                      child: const Icon(Icons.skip_previous, size: 36),
                    ),
                  ),

                  // Play / Pause (Giant)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: tokens.accent,
                        foregroundColor: tokens.surface,
                        elevation: 4,
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        playerCtrl.togglePlayPause();
                      },
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 52,
                      ),
                    ),
                  ),

                  // Next
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: tokens.surface2,
                        foregroundColor: tokens.text,
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        playerCtrl.skipNext();
                      },
                      child: const Icon(Icons.skip_next, size: 36),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // 5. Bottom Mic Toggle
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: voiceState.isListening
                          ? tokens.destructive
                          : tokens.statusOnline,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    voiceState.isListening ? Icons.mic_off : Icons.mic,
                    color: voiceState.isListening
                        ? tokens.destructive
                        : tokens.statusOnline,
                  ),
                  label: Text(
                    voiceState.isListening ? 'Stop Listening' : 'Start Listening',
                    style: MelodiaTokens.headline.copyWith(
                      color: voiceState.isListening
                          ? tokens.destructive
                          : tokens.statusOnline,
                    ),
                  ),
                  onPressed: () {
                    if (voiceState.isListening) {
                      voiceCtrl.stopListening();
                    } else {
                      voiceCtrl.startListening(rideMode: true);
                    }
                  },
                ),
              ),
              const SizedBox(height: MelodiaTokens.spacingSm),
            ],
          ),
        ),
      ),
    );
  }
}
