import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../theme/tokens.dart';
import 'track_more_menu.dart';

class TrackRow extends ConsumerWidget {
  const TrackRow({
    super.key,
    required this.track,
    this.index,
    this.isCurrentTrack = false,
    this.isPlaying = false,
    this.onTap,
    this.onPlayNext,
    this.onAddToQueue,
    this.onRemoveFromPlaylist,
    this.trailing,
  });

  final Track track;
  final int? index;
  final bool isCurrentTrack;
  final bool isPlaying;
  final VoidCallback? onTap;
  final ValueChanged<Track>? onPlayNext;
  final ValueChanged<Track>? onAddToQueue;
  final VoidCallback? onRemoveFromPlaylist;
  final Widget? trailing;

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Semantics(
      button: true,
      label: '${track.title} by ${track.artist}',
      child: Material(
        color: tokens.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingLg,
                    ),
                    child: Row(
                      children: [
                        if (track.thumbnail != null &&
                            track.thumbnail!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              MelodiaTokens.radiusArtworkSm,
                            ),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: CachedNetworkImage(
                                imageUrl: track.thumbnail!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: tokens.surface2,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: tokens.surface2,
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: tokens.textTertiary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (index != null)
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index! + 1}',
                              style: MelodiaTokens.body.copyWith(
                                color: isCurrentTrack
                                    ? tokens.accent
                                    : tokens.textSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(width: MelodiaTokens.spacingMd),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MelodiaTokens.body.copyWith(
                                  color: isCurrentTrack
                                      ? tokens.accent
                                      : tokens.text,
                                  fontWeight: isCurrentTrack
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MelodiaTokens.footnote.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null)
                          trailing!
                        else ...[
                          if (isCurrentTrack && isPlaying)
                            _EqualizerBars(tokens: tokens)
                          else
                            Text(
                              _formatDuration(track.durationSeconds),
                              style: MelodiaTokens.footnote.copyWith(
                                color: tokens.textTertiary,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: tokens.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => showTrackMoreMenu(
                              context: context,
                              ref: ref,
                              track: track,
                              onRemoveFromPlaylist: onRemoveFromPlaylist,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Container(
                    height: 0.5,
                    color: tokens.separator,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.tokens});

  final MelodiaTokens tokens;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return SizedBox(
          width: 16,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(0.4 + 0.6 * _anim.value),
              _bar(1.0 - 0.7 * _anim.value),
              _bar(0.2 + 0.8 * _anim.value),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double fraction) {
    return Container(
      width: 3,
      height: (16 * fraction).clamp(3.0, 16.0),
      decoration: BoxDecoration(
        color: widget.tokens.accent,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
