import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_controller.dart';
import '../../downloads/offline_mode.dart';
import '../../theme/tokens.dart';

/// Slim non-blocking status banner shown below status bar when offline or server unreachable.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final offlineState = ref.watch(offlineModeControllerProvider);
    final isOfflineMode = offlineState.isOffline;

    if (connectivity.isOnline && !isOfflineMode) {
      return const SizedBox.shrink();
    }

    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final isOffline = connectivity.status == ConnectivityStatus.noInternet || isOfflineMode;

    String bannerText;
    if (isOfflineMode) {
      bannerText = 'Offline mode \u2014 showing downloaded music only';
    } else if (isOffline) {
      bannerText = "You're offline";
    } else {
      bannerText = "Can't reach the music server. Trying again...";
    }

    return Container(
      width: double.infinity,
      color: tokens.surface2,
      padding: const EdgeInsets.symmetric(
        horizontal: MelodiaTokens.spacingLg,
        vertical: MelodiaTokens.spacingSm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              isOffline ? Icons.offline_pin_rounded : Icons.cloud_off_rounded,
              size: 16,
              color: isOffline ? tokens.accent : tokens.statusWarning,
            ),
            const SizedBox(width: MelodiaTokens.spacingSm),
            Expanded(
              child: Text(
                bannerText,
                style: MelodiaTokens.footnote.copyWith(
                  color: tokens.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOfflineMode && offlineState.isManual) ...[
              const SizedBox(width: MelodiaTokens.spacingSm),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MelodiaTokens.spacingSm,
                  ),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () {
                  ref.read(offlineModeProvider.notifier).setManualOffline(false);
                },
                child: Text(
                  'Exit',
                  style: MelodiaTokens.footnote.copyWith(
                    color: tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else if (!isOffline) ...[
              const SizedBox(width: MelodiaTokens.spacingSm),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MelodiaTokens.spacingSm,
                  ),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () {
                  ref.read(connectivityProvider.notifier).retryNow();
                },
                child: Text(
                  'Retry',
                  style: MelodiaTokens.footnote.copyWith(
                    color: tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

