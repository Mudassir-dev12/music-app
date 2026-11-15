import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/user_data_providers.dart';
import '../../theme/tokens.dart';

/// Heart (like) toggle button for tracks with haptic feedback and optimistic update.
class LikeHeartButton extends ConsumerWidget {
  const LikeHeartButton({
    super.key,
    required this.track,
    this.size = 24.0,
  });

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final likedIds = ref.watch(likedIdsProvider).valueOrNull ?? <String>{};
    final isLiked = likedIds.contains(track.videoId);

    return Semantics(
      button: true,
      label: isLiked ? 'Unlike ${track.title}' : 'Like ${track.title}',
      child: IconButton(
        iconSize: size,
        splashRadius: size,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey<bool>(isLiked),
            color: isLiked ? tokens.accent : tokens.textSecondary,
            size: size,
          ),
        ),
        onPressed: () async {
          HapticFeedback.lightImpact();
          try {
            await ref.read(likedIdsProvider.notifier).toggleLike(track);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to update like status. Please try again.',
                    style: MelodiaTokens.footnote.copyWith(color: tokens.text),
                  ),
                  backgroundColor: tokens.surface2,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
