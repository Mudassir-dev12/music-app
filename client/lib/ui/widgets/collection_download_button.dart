import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../downloads/collection_sync_controller.dart';
import '../../downloads/download_repository.dart';
import '../../theme/tokens.dart';

class CollectionDownloadButton extends ConsumerWidget {
  const CollectionDownloadButton({
    super.key,
    required this.collectionKey,
    required this.title,
    required this.tracks,
  });

  final String collectionKey;
  final String title;
  final List<Track> tracks;

  Future<void> _handleToggle(BuildContext context, WidgetRef ref) async {
    final isSupported = ref.read(isDownloadSupportedProvider);
    if (!isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloads are available on mobile and desktop apps.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final notifier = ref.read(collectionSyncNotifierProvider.notifier);
    final isKeepOffline = notifier.isKeepOffline(collectionKey);

    if (isKeepOffline) {
      final tokens = Theme.of(context).extension<MelodiaTokens>()!;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
          ),
          title: Text(
            'Keep offline turned off',
            style: MelodiaTokens.title3.copyWith(color: tokens.text),
          ),
          content: Text(
            'Keep downloaded files on device or remove them?',
            style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Keep files',
                style: MelodiaTokens.headline.copyWith(color: tokens.accent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Remove files',
                style: MelodiaTokens.headline.copyWith(color: tokens.destructive),
              ),
            ),
          ],
        ),
      );

      if (result != null) {
        await notifier.setKeepOffline(
          collectionKey: collectionKey,
          title: title,
          tracks: tracks,
          enabled: false,
          removeFiles: result,
        );
      }
    } else {
      await notifier.setKeepOffline(
        collectionKey: collectionKey,
        title: title,
        tracks: tracks,
        enabled: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $title...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final isSupported = ref.watch(isDownloadSupportedProvider);
    if (!isSupported) {
      return const SizedBox.shrink();
    }

    ref.watch(collectionSyncProvider);
    final notifier = ref.read(collectionSyncProvider.notifier);
    final syncInfo = notifier.getCollectionSync(collectionKey, tracks.length);
    final isKeepOffline = syncInfo?.keepOffline ?? false;
    final downloaded = syncInfo?.downloadedTracks ?? 0;
    final total = tracks.length;

    if (isKeepOffline) {
      final isComplete = total > 0 && downloaded >= total;
      final label = isComplete
          ? 'Downloaded'
          : '$downloaded of $total downloaded';

      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.accent,
          side: BorderSide(color: tokens.accent),
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingMd,
            vertical: MelodiaTokens.spacingSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          ),
        ),
        icon: Icon(
          isComplete ? Icons.download_done_rounded : Icons.downloading_rounded,
          size: 18,
          color: tokens.accent,
        ),
        label: Text(
          label,
          style: MelodiaTokens.subhead.copyWith(
            color: tokens.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () => _handleToggle(context, ref),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textSecondary,
        side: BorderSide(color: tokens.separator),
        padding: const EdgeInsets.symmetric(
          horizontal: MelodiaTokens.spacingMd,
          vertical: MelodiaTokens.spacingSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
        ),
      ),
      icon: Icon(
        Icons.arrow_circle_down_rounded,
        size: 18,
        color: tokens.textSecondary,
      ),
      label: Text(
        'Download',
        style: MelodiaTokens.subhead.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _handleToggle(context, ref),
    );
  }
}
