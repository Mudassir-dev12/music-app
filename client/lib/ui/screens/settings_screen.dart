import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart' as config;
import '../../core/connectivity/connectivity_controller.dart';
import '../../data/user_data_providers.dart';
import '../../downloads/download_repository.dart';
import '../../downloads/offline_mode.dart';
import '../../player/audio_cache_provider.dart';
import '../../player/autoplay_controller.dart';
import '../../player/prefetch_coordinator.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';
import '../voice/voice_settings_section.dart';
import '../widgets/diagnostics_sheet.dart';
import '../widgets/server_url_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;

  Future<void> _showClearAudioCacheDialog(BuildContext context, int usedBytes) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final sizeFormatted = _formatSize(usedBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Clear Audio Cache?',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Text(
          'This will free up $sizeFormatted of cached audio. Pinned tracks and downloaded songs are kept safe.',
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
              'Clear Cache',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final cache = ref.read(audioCacheProvider);
      await cache.clearCache();
      if (context.mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Audio cache cleared',
              style: MelodiaTokens.footnote.copyWith(color: tokens.text),
            ),
            backgroundColor: tokens.surface2,
          ),
        );
      }
    }
  }

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

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1000) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  Future<void> _showRemoveAllDownloadsDialog(
      BuildContext context, WidgetRef ref) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final tracks = ref.read(downloadedTracksProvider);
    final count = tracks.length;
    final totalBytes = tracks.fold<int>(0, (sum, t) => sum + t.byteSize);
    final sizeFormatted = _formatSize(totalBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Remove All Downloads?',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Text(
          'This will delete $count downloaded songs ($sizeFormatted) from your device storage.',
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
              'Remove All',
              style: MelodiaTokens.subhead.copyWith(color: tokens.text),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(downloadManagerProvider).removeAllDownloads();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed all downloaded songs.',
              style: MelodiaTokens.footnote.copyWith(color: tokens.text),
            ),
            backgroundColor: tokens.surface2,
          ),
        );
      }
    }
  }

  Future<void> _showStorageCapPicker(
      BuildContext context, WidgetRef ref, int currentCap) async {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final choices = [
      (label: '500 MB', mb: 500),
      (label: '1 GB', mb: 1024),
      (label: '2 GB', mb: 2048),
      (label: '5 GB', mb: 5120),
      (label: '10 GB', mb: 10240),
      (label: 'None (unlimited)', mb: 0),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
        ),
        title: Text(
          'Storage Limit',
          style: MelodiaTokens.title3.copyWith(color: tokens.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices.map((c) {
            final isSelected = c.mb == currentCap;
            return ListTile(
              title: Text(
                c.label,
                style: MelodiaTokens.body.copyWith(
                  color: isSelected ? tokens.accent : tokens.text,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_rounded, color: tokens.accent, size: 20)
                  : null,
              onTap: () {
                ref.read(storageCapProvider.notifier).setCap(c.mb);
                ref.read(downloadManagerProvider).setStorageCapMb(c.mb);
                Navigator.of(dialogCtx).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

          // 2. PLAYBACK
          _buildSectionHeader(tokens, 'PLAYBACK'),
          Material(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: Icon(Icons.autorenew_rounded, color: tokens.accent),
                  title: Text(
                    'Autoplay Similar Songs',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    'Keep playing similar music when your queue ends',
                    style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                  ),
                  value: ref.watch(autoplayEnabledProvider),
                  activeTrackColor: tokens.accent,
                  onChanged: (val) {
                    ref.read(autoplayEnabledProvider.notifier).setAutoplay(val);
                  },
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 16),
                Padding(
                  padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: tokens.accent),
                          const SizedBox(width: MelodiaTokens.spacingSm),
                          Text(
                            'Smart Prefetch',
                            style: MelodiaTokens.headline.copyWith(color: tokens.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: MelodiaTokens.spacingXs),
                      Text(
                        'Pre-warm upcoming search, queue, and album tracks for instant playback',
                        style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                      ),
                      const SizedBox(height: MelodiaTokens.spacingSm),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<SmartPrefetchMode>(
                          segments: const [
                            ButtonSegment(
                              value: SmartPrefetchMode.off,
                              label: Text('Off'),
                            ),
                            ButtonSegment(
                              value: SmartPrefetchMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: SmartPrefetchMode.full,
                              label: Text('Full'),
                            ),
                          ],
                          selected: {ref.watch(smartPrefetchModeProvider)},
                          onSelectionChanged: (selected) {
                            ref
                                .read(smartPrefetchModeProvider.notifier)
                                .setMode(selected.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 16),
                FutureBuilder<List<int>>(
                  future: Future.wait([
                    ref.watch(audioCacheProvider).totalBytesUsed(),
                    ref.watch(audioCacheProvider).getCapBytes(),
                  ]),
                  builder: (context, snapshot) {
                    final used = snapshot.data != null ? snapshot.data![0] : 0;
                    final cap = snapshot.data != null ? snapshot.data![1] : 500 * 1024 * 1024;
                    final capMb = (cap / (1024 * 1024)).round();

                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.sd_storage_rounded, color: tokens.accent),
                          title: Text(
                            'Audio Cache',
                            style: MelodiaTokens.headline.copyWith(color: tokens.text),
                          ),
                          subtitle: Text(
                            'Used: ${_formatSize(used)} (Cap: ${_formatSize(cap)})\nNot counted as downloaded songs',
                            style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                          ),
                          trailing: DropdownButton<int>(
                            value: [100, 250, 500, 1024, 2048].contains(capMb) ? capMb : 500,
                            underline: const SizedBox.shrink(),
                            dropdownColor: tokens.surface,
                            items: const [
                              DropdownMenuItem(value: 100, child: Text('100 MB')),
                              DropdownMenuItem(value: 250, child: Text('250 MB')),
                              DropdownMenuItem(value: 500, child: Text('500 MB')),
                              DropdownMenuItem(value: 1024, child: Text('1 GB')),
                              DropdownMenuItem(value: 2048, child: Text('2 GB')),
                            ],
                            onChanged: (newMb) {
                              if (newMb != null) {
                                ref.read(audioCacheProvider).setCapBytes(newMb * 1024 * 1024);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        if (used > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: tokens.destructive),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text('Clear audio cache'),
                                onPressed: () => _showClearAudioCacheDialog(context, used),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingXl),

          // VOICE CONTROL & RIDE MODE
          const VoiceSettingsSection(),
          const SizedBox(height: MelodiaTokens.spacingXl),

          // 3. LIBRARY
          _buildSectionHeader(tokens, 'LIBRARY'),
          Material(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
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

          // 3. DOWNLOADS & STORAGE
          _buildSectionHeader(tokens, 'DOWNLOADS & STORAGE'),
          Material(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.cloud_off_rounded,
                    color: ref.watch(isOfflineModeProvider)
                        ? tokens.accent
                        : tokens.textSecondary,
                  ),
                  title: Text(
                    'Offline Mode',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    'Only play downloaded music',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  value: ref.watch(isOfflineModeProvider),
                  activeTrackColor: tokens.accent,
                  onChanged: (_) {
                    ref.read(offlineModeProvider.notifier).toggleManualOffline();
                  },
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 52),
                SwitchListTile(
                  secondary: Icon(
                    Icons.wifi_rounded,
                    color: tokens.textSecondary,
                  ),
                  title: Text(
                    'Download over Wi-Fi only',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  value: ref.watch(wifiOnlyProvider),
                  activeTrackColor: tokens.accent,
                  onChanged: (val) {
                    ref.read(wifiOnlyProvider.notifier).set(val);
                    ref.read(downloadManagerProvider).setWifiOnly(val);
                  },
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 52),
                ListTile(
                  leading: Icon(
                    Icons.disc_full_rounded,
                    color: tokens.textSecondary,
                  ),
                  title: Text(
                    'Storage Limit',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    ref.watch(storageCapProvider) == 0
                        ? 'Unlimited'
                        : ref.watch(storageCapProvider) >= 1024
                            ? '${ref.watch(storageCapProvider) ~/ 1024} GB'
                            : '${ref.watch(storageCapProvider)} MB',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
                  onTap: () => _showStorageCapPicker(
                    context,
                    ref,
                    ref.read(storageCapProvider),
                  ),
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 52),
                ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: tokens.textSecondary,
                  ),
                  title: Text(
                    'Downloaded Music',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  subtitle: Text(
                    '${ref.watch(downloadedTracksProvider).length} songs • ${_formatSize(ref.watch(downloadedTracksProvider).fold<int>(0, (s, t) => s + t.byteSize))}',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
                  onTap: () => context.push('/downloaded'),
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 52),
                Consumer(
                  builder: (context, ref, _) {
                    final limitsAsync = ref.watch(downloadLimitsProvider);
                    final subtitle = limitsAsync.when(
                      data: (l) => '${l.remainingDownloadMb} MB remaining today',
                      loading: () => 'Loading quota...',
                      error: (_, __) => 'Offline (quota unavailable)',
                    );
                    return ListTile(
                      leading: Icon(
                        Icons.speed_rounded,
                        color: tokens.textSecondary,
                      ),
                      title: Text(
                        "Today's Download Quota",
                        style: MelodiaTokens.headline.copyWith(color: tokens.text),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                      ),
                    );
                  },
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 52),
                ListTile(
                  leading: Icon(
                    Icons.image_not_supported_outlined,
                    color: tokens.textSecondary,
                  ),
                  title: Text(
                    'Clear Image Cache',
                    style: MelodiaTokens.headline.copyWith(color: tokens.text),
                  ),
                  onTap: () {
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Image cache cleared',
                          style: MelodiaTokens.footnote.copyWith(color: tokens.text),
                        ),
                        backgroundColor: tokens.surface2,
                      ),
                    );
                  },
                ),
                Divider(color: tokens.separator, height: 0.5, indent: 52),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: tokens.destructive,
                  ),
                  title: Text(
                    'Remove All Downloads',
                    style: MelodiaTokens.headline.copyWith(color: tokens.destructive),
                  ),
                  onTap: () => _showRemoveAllDownloadsDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: MelodiaTokens.spacingXl),

          // 3. ACCOUNT
          _buildSectionHeader(tokens, 'ACCOUNT'),
          Material(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
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
          Material(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
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
                  onTap: () {
                    setState(() {
                      _versionTapCount++;
                    });
                    if (_versionTapCount >= 7 || kDebugMode) {
                      DiagnosticsSheet.show(context);
                    }
                  },
                ),
                if (kDebugMode || _versionTapCount >= 7) ...[
                  Divider(
                    color: tokens.separator,
                    height: 0.5,
                    indent: 16,
                  ),
                  ListTile(
                    leading: Icon(Icons.analytics_outlined, color: tokens.accent),
                    title: Text(
                      'Playback Diagnostics',
                      style: MelodiaTokens.headline.copyWith(color: tokens.text),
                    ),
                    subtitle: Text(
                      'Inspect latency, cache hit rate, and prefetch metrics',
                      style: MelodiaTokens.footnote.copyWith(color: tokens.textSecondary),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: tokens.textSecondary),
                    onTap: () => DiagnosticsSheet.show(context),
                  ),
                ],
                Divider(
                  color: tokens.separator,
                  height: 0.5,
                  indent: 16,
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final conn = ref.watch(connectivityProvider);
                    final dotColor = switch (conn.status) {
                      ConnectivityStatus.online => tokens.statusOnline,
                      ConnectivityStatus.reconnecting => tokens.statusWarning,
                      ConnectivityStatus.serverDown => tokens.statusOffline,
                      ConnectivityStatus.noInternet => tokens.statusOffline,
                    };
                    final statusLabel = switch (conn.status) {
                      ConnectivityStatus.online => conn.latency != null
                          ? 'Online (${conn.latency!.inMilliseconds} ms)'
                          : 'Online',
                      ConnectivityStatus.reconnecting => 'Reconnecting...',
                      ConnectivityStatus.serverDown => 'Server unreachable',
                      ConnectivityStatus.noInternet => 'No internet',
                    };
                    final serverDisplay = kReleaseMode
                        ? (Uri.tryParse(config.apiUrl)?.host.isNotEmpty == true
                            ? Uri.parse(config.apiUrl).host
                            : config.apiUrl)
                        : config.apiUrl;
                    final versionLabel = conn.serverVersion != null
                        ? 'Backend v${conn.serverVersion}'
                        : 'Backend status';

                    return ListTile(
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      title: Text(
                        'Server Status',
                        style: MelodiaTokens.headline.copyWith(color: tokens.text),
                      ),
                      subtitle: Text(
                        '$serverDisplay\n$statusLabel • $versionLabel',
                        style: MelodiaTokens.caption.copyWith(color: tokens.textSecondary),
                      ),
                      isThreeLine: true,
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tokens.separator),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final ok = await ref.read(connectivityProvider.notifier).retryNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok ? 'Server connection verified' : 'Could not reach server',
                                  style: MelodiaTokens.footnote.copyWith(color: tokens.text),
                                ),
                                backgroundColor: tokens.surface2,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Test connection',
                          style: MelodiaTokens.caption.copyWith(
                            color: tokens.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
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
                    trailing: Icon(
                      Icons.edit_outlined,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                    onTap: () => showServerUrlDialog(context, ref),
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
