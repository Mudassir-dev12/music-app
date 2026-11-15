import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart' as config;
import '../../data/user_data_providers.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showClearHistoryDialog(BuildContext context, WidgetRef ref) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Clear Listening History?',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Text(
          'This will clear your listening history across all devices.',
          style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.destructive,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Clear History',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(historyProvider.notifier).clearHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Listening history cleared',
              style: MelodiaTokens.footnote.copyWith(color: tokens.text),
            ),
            backgroundColor: tokens.surface2,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final themeAsync = ref.watch(themeControllerProvider);
    final currentTheme = themeAsync.valueOrNull ?? ThemeMode.system;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        surfaceTintColor: tokens.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.accent,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/listen-now');
            }
          },
        ),
        title: Text(
          'Settings',
          style: MelodiaTokens.title2.copyWith(color: tokens.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MelodiaTokens.spacingLg,
          vertical: MelodiaTokens.spacingMd,
        ),
        children: [
          // 1. APPEARANCE
          _buildSectionHeader(tokens, 'APPEARANCE'),
          Container(
            padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: MelodiaTokens.headline.copyWith(color: tokens.text),
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {currentTheme},
                    onSelectionChanged: (selected) {
                      ref
                          .read(themeControllerProvider.notifier)
                          .setTheme(selected.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingXl),

          // 2. LIBRARY
          _buildSectionHeader(tokens, 'LIBRARY'),
          Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.history_rounded,
                    color: tokens.accent,
                  ),
                  title: Text(
                    'Recently Played',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.textTertiary,
                  ),
                  onTap: () => context.push('/history'),
                ),
                Divider(
                  color: tokens.separator,
                  height: 0.5,
                  indent: 52,
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: tokens.destructive,
                  ),
                  title: Text(
                    'Clear Listening History',
                    style: MelodiaTokens.headline.copyWith(
                      color: tokens.destructive,
                    ),
                  ),
                  onTap: () => _showClearHistoryDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingXl),

          // 3. ACCOUNT
          _buildSectionHeader(tokens, 'ACCOUNT'),
          Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            ),
            child: ListTile(
              leading: Icon(
                Icons.person_outline_rounded,
                color: tokens.textTertiary,
              ),
              title: Text(
                'Sign in and sync',
                style: MelodiaTokens.headline.copyWith(
                  color: tokens.textTertiary,
                ),
              ),
              subtitle: Text(
                'Coming later in Phase 8',
                style: MelodiaTokens.caption.copyWith(
                  color: tokens.textTertiary,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Paused',
                  style: MelodiaTokens.caption.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
              ),
              enabled: false,
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingXl),

          // 4. ABOUT
          _buildSectionHeader(tokens, 'ABOUT'),
          Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Melodia',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  trailing: Text(
                    '1.0.0+1',
                    style: MelodiaTokens.body.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                if (kDebugMode) ...[
                  Divider(
                    color: tokens.separator,
                    height: 0.5,
                    indent: 16,
                  ),
                  ListTile(
                    title: Text(
                      'API Base URL',
                      style: MelodiaTokens.headline.copyWith(color: tokens.text),
                    ),
                    subtitle: Text(
                      config.apiUrl,
                      style: MelodiaTokens.footnote.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 120), // Mini player inset
        ],
      ),
    );
  }

  Widget _buildSectionHeader(MelodiaTokens tokens, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MelodiaTokens.spacingSm,
        0,
        MelodiaTokens.spacingSm,
        MelodiaTokens.spacingSm,
      ),
      child: Text(
        title,
        style: MelodiaTokens.caption.copyWith(
          color: tokens.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
