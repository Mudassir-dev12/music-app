import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/tokens.dart';
import '../../voice/voice_controller.dart';

class VoiceFirstRunScreen extends ConsumerWidget {
  const VoiceFirstRunScreen({super.key});

  static const String _kVoiceOnboardingSeenKey = 'melodia_voice_onboarding_seen';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kVoiceOnboardingSeenKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceOnboardingSeenKey, true);
  }

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const VoiceFirstRunScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.all(MelodiaTokens.spacingXl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: tokens.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.two_wheeler_rounded, size: 36, color: tokens.accent),
          ),
          const SizedBox(height: MelodiaTokens.spacingLg),
          Text(
            'Hands-Free Voice Control',
            style: MelodiaTokens.title2.copyWith(color: tokens.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MelodiaTokens.spacingSm),
          Text(
            'Ride your bike with earbuds connected and speak naturally to play, pause, change songs, and adjust volume.',
            style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MelodiaTokens.spacingLg),
          Container(
            padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 20, color: tokens.statusOnline),
                const SizedBox(width: MelodiaTokens.spacingSm),
                Expanded(
                  child: Text(
                    '100% on-device. Audio is never recorded or uploaded to any server.',
                    style: MelodiaTokens.caption.copyWith(color: tokens.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingXl),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await markSeen();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ref.read(voiceControllerProvider.notifier).startListening(rideMode: true);
                }
              },
              child: Text(
                'Get Started',
                style: MelodiaTokens.headline.copyWith(color: tokens.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
