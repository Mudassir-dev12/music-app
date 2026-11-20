import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../voice/voice_settings.dart';
import 'voice_help_sheet.dart';

class VoiceSettingsSection extends ConsumerWidget {
  const VoiceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final settings = ref.watch(voiceSettingsProvider);
    final notifier = ref.read(voiceSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VOICE CONTROL & RIDE MODE',
                style: MelodiaTokens.caption.copyWith(
                  color: tokens.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => VoiceHelpSheet.show(context),
                child: Text(
                  'Commands',
                  style: MelodiaTokens.caption.copyWith(color: tokens.accent),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
          child: Material(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Ride Mode Auto-start',
                    style: MelodiaTokens.body.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    'Start listening automatically when opening Ride Mode',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  // ignore: deprecated_member_use
                  activeColor: tokens.accent,
                  value: settings.rideModeAutoStart,
                  onChanged: (val) => notifier.setRideModeAutoStart(val),
                ),
                Divider(height: 1, color: tokens.separator),
                SwitchListTile(
                  title: Text(
                    'Spoken Confirmations',
                    style: MelodiaTokens.body.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    'Hear short spoken replies so you never need the screen',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  // ignore: deprecated_member_use
                  activeColor: tokens.accent,
                  value: settings.confirmSpoken,
                  onChanged: (val) => notifier.setConfirmSpoken(val),
                ),
                Divider(height: 1, color: tokens.separator),
                ListTile(
                  title: Text(
                    'Voice Language',
                    style: MelodiaTokens.body.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    'Select primary recognition language',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.preferredLanguage,
                    dropdownColor: tokens.surface,
                    style: MelodiaTokens.subhead.copyWith(color: tokens.text),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Auto-detect')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ur', child: Text('Urdu (اردو)')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setPreferredLanguage(val);
                    },
                  ),
                ),
                Divider(height: 1, color: tokens.separator),
                SwitchListTile(
                  title: Text(
                    'Smart Understanding (AI Fallback)',
                    style: MelodiaTokens.body.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    'Uses optional backend AI when local parser finds no match',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  // ignore: deprecated_member_use
                  activeColor: tokens.accent,
                  value: settings.aiFallbackEnabled,
                  onChanged: (val) => notifier.setAiFallbackEnabled(val),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
