import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_controller.dart';
import '../../theme/tokens.dart';

/// Slim non-blocking status banner shown below status bar when connection is not online.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    if (connectivity.isOnline) {
      return const SizedBox.shrink();
    }

    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final isOffline = connectivity.status == ConnectivityStatus.noInternet;

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
              isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              size: 16,
              color: isOffline ? tokens.destructive : tokens.statusWarning,
            ),
            const SizedBox(width: MelodiaTokens.spacingSm),
            Expanded(
              child: Text(
                isOffline
                    ? "You're offline"
                    : "Can't reach the music server. Trying again...",
                style: MelodiaTokens.footnote.copyWith(
                  color: tokens.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isOffline) ...[
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

