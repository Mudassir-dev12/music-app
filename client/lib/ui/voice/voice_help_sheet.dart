import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class VoiceHelpSheet extends StatelessWidget {
  const VoiceHelpSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const VoiceHelpSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MelodiaTokens.spacingLg,
        vertical: MelodiaTokens.spacingXl,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingLg),
          Text(
            'Voice Commands',
            style: MelodiaTokens.title2.copyWith(color: tokens.text),
          ),
          const SizedBox(height: MelodiaTokens.spacingXs),
          Text(
            'Speak naturally in English or Urdu while riding or listening.',
            style: MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: MelodiaTokens.spacingLg),
          Expanded(
            child: ListView(
              children: [
                _buildCategory(
                  tokens,
                  icon: Icons.play_circle_outline,
                  title: 'Playback',
                  commands: const [
                    '"play"',
                    '"pause"',
                    '"next song"',
                    '"previous"',
                    '"restart song"',
                  ],
                ),
                _buildCategory(
                  tokens,
                  icon: Icons.volume_up,
                  title: 'Volume & Seek',
                  commands: const [
                    '"turn it up"',
                    '"volume down"',
                    '"volume 50 percent"',
                    '"forward 30 seconds"',
                    '"back 10 seconds"',
                  ],
                ),
                _buildCategory(
                  tokens,
                  icon: Icons.search,
                  title: 'Search & Music',
                  commands: const [
                    '"play Tum Hi Ho by Arijit Singh"',
                    '"play the album Aashiqui 2"',
                    '"play my liked songs"',
                    '"play playlist Gym"',
                    '"play downloaded songs"',
                  ],
                ),
                _buildCategory(
                  tokens,
                  icon: Icons.timer,
                  title: 'Timer & Modes',
                  commands: const [
                    '"stop in 20 minutes"',
                    '"cancel sleep timer"',
                    '"shuffle on"',
                    '"repeat one"',
                    '"turn autoplay off"',
                  ],
                ),
                _buildCategory(
                  tokens,
                  icon: Icons.translate,
                  title: 'Urdu (اردو)',
                  commands: const [
                    '"Arijit Singh ke gane chalao"',
                    '"ruko"',
                    '"agla gana"',
                    '"awaz kam karo"',
                    '"pasandeeda gane chalao"',
                    '"عاطف اسلم کے گانے چلاؤ"',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(
    MelodiaTokens tokens, {
    required IconData icon,
    required String title,
    required List<String> commands,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: MelodiaTokens.spacingLg),
      padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: tokens.accent),
              const SizedBox(width: MelodiaTokens.spacingSm),
              Text(
                title,
                style: MelodiaTokens.headline.copyWith(color: tokens.text),
              ),
            ],
          ),
          const SizedBox(height: MelodiaTokens.spacingSm),
          Wrap(
            spacing: MelodiaTokens.spacingSm,
            runSpacing: MelodiaTokens.spacingXs,
            children: commands.map((c) {
              return Chip(
                backgroundColor: tokens.surface,
                side: BorderSide(color: tokens.separator),
                label: Text(
                  c,
                  style: MelodiaTokens.caption.copyWith(color: tokens.text),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
