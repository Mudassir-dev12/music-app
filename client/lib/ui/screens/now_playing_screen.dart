import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../player/player_controller.dart';
import '../../player/player_state.dart';
import '../../player/queue.dart';
import '../../theme/tokens.dart';
import '../widgets/like_button.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/marquee_text.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/track_more_menu.dart';
import '../widgets/volume_slider.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _showLyrics = false;
  int _desktopTab = 0;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: const SpringCurve(),
      ),
    );

    // Initial scale state
    final isPlaying = ref.read(playerControllerProvider).isPlaying;
    if (isPlaying) {
      _scaleController.value = 1.0;
    } else {
      _scaleController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _showMoreMenu(BuildContext context, Track currentTrack) {
    showTrackMoreMenu(
      context: context,
      ref: ref,
      track: currentTrack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final currentTrack = playerState.queue.currentTrack;

    // Update artwork scale on play/pause transition
    if (playerState.isPlaying && _scaleController.status != AnimationStatus.forward && _scaleController.value < 1.0) {
      _scaleController.forward();
    } else if (!playerState.isPlaying && _scaleController.status != AnimationStatus.reverse && _scaleController.value > 0.0) {
      _scaleController.reverse();
    }

    if (currentTrack == null) {
      return Scaffold(
        backgroundColor: tokens.background,
        appBar: AppBar(
          backgroundColor: tokens.transparent,
          leading: IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.text),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Nothing playing',
            style: MelodiaTokens.body.copyWith(color: tokens.textSecondary),
          ),
        ),
      );
    }

    final isPlaying = playerState.isPlaying;
    final isShuffle = playerState.queue.shuffle;
    final repeatMode = playerState.queue.repeat;

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          // 1. Scaled blurred artwork background
          Positioned.fill(
            child: currentTrack.thumbnail != null && currentTrack.thumbnail!.isNotEmpty
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Transform.scale(
                      scale: 1.4,
                      child: CachedNetworkImage(
                        imageUrl: currentTrack.thumbnail!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : Container(color: tokens.surface),
          ),
          // Dark gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tokens.background.withValues(alpha: 0.5),
                    tokens.background.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // 2. Foreground content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= MelodiaTokens.breakpointTablet;
                final artworkSize = (constraints.maxWidth - 64).clamp(180.0, 360.0);

                if (isDesktop) {
                  return _buildDesktopLayout(
                    context,
                    tokens,
                    controller,
                    playerState,
                    currentTrack,
                    isPlaying,
                    isShuffle,
                    repeatMode,
                  );
                }

                // Phone layout with vertical drag-to-dismiss
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                      Navigator.pop(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelodiaTokens.spacingXl,
                    ),
                    child: Column(
                      children: [
                        // Grabber and close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: tokens.text,
                                size: 32,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: tokens.textTertiary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: tokens.text,
                                size: 24,
                              ),
                              onPressed: () => _showMoreMenu(context, currentTrack),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Artwork or Lyrics
                        if (_showLyrics)
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tokens.surface.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
                                ),
                                child: LyricsView(videoId: currentTrack.videoId),
                              ),
                            ),
                          )
                        else ...[
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
                              child: Container(
                                width: artworkSize,
                                height: artworkSize,
                                decoration: BoxDecoration(
                                  color: tokens.surface2,
                                  boxShadow: MelodiaTokens.cardShadow,
                                ),
                                child: currentTrack.thumbnail != null &&
                                        currentTrack.thumbnail!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: currentTrack.thumbnail!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: tokens.surface2),
                                        errorWidget: (_, __, ___) => Icon(
                                          Icons.music_note_rounded,
                                          size: 64,
                                          color: tokens.textTertiary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.music_note_rounded,
                                        size: 64,
                                        color: tokens.textTertiary,
                                      ),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],

                        // Title & Artist
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MarqueeText(
                                    text: currentTrack.title,
                                    style: MelodiaTokens.title2.copyWith(
                                      color: tokens.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentTrack.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MelodiaTokens.title3.copyWith(
                                      color: tokens.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            LikeHeartButton(track: currentTrack, size: 28),
                          ],
                        ),

                        const SizedBox(height: MelodiaTokens.spacingLg),

                        // Scrubber
                        ScrubBar(
                          position: playerState.position,
                          duration: playerState.duration,
                          onSeek: (pos) => controller.seekTo(pos),
                        ),

                        const SizedBox(height: MelodiaTokens.spacingMd),

                        // Transport Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.skip_previous_rounded,
                                color: tokens.text,
                                size: 44,
                              ),
                              onPressed: () => controller.skipPrevious(),
                            ),
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: tokens.text,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: tokens.background,
                                  size: 44,
                                ),
                                onPressed: () => controller.togglePlayPause(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.skip_next_rounded,
                                color: tokens.text,
                                size: 44,
                              ),
                              onPressed: () => controller.skipNext(),
                            ),
                          ],
                        ),

                        const SizedBox(height: MelodiaTokens.spacingMd),

                        // Volume Slider (web / desktop only)
                        if (kIsWeb)
                          VolumeSlider(
                            volume: playerState.volume,
                            onChanged: (v) => controller.setVolume(v),
                          ),

                        const Spacer(),

                        // Bottom Row: Lyrics, Shuffle, Repeat, Queue
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.format_quote_rounded,
                                color: _showLyrics ? tokens.accent : tokens.textSecondary,
                                size: 24,
                              ),
                              tooltip: 'Lyrics',
                              onPressed: () {
                                setState(() {
                                  _showLyrics = !_showLyrics;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: isShuffle ? tokens.accent : tokens.textSecondary,
                                size: 22,
                              ),
                              tooltip: 'Shuffle',
                              onPressed: () => controller.toggleShuffle(),
                            ),
                            IconButton(
                              icon: Icon(
                                repeatMode == RepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: repeatMode != RepeatMode.off
                                    ? tokens.accent
                                    : tokens.textSecondary,
                                size: 22,
                              ),
                              tooltip: 'Repeat',
                              onPressed: () => controller.cycleRepeat(),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.queue_music_rounded,
                                color: tokens.textSecondary,
                                size: 22,
                              ),
                              tooltip: 'Queue',
                              onPressed: () => context.push('/queue'),
                            ),
                          ],
                        ),

                        const SizedBox(height: MelodiaTokens.spacingMd),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    MelodiaTokens tokens,
    PlayerController controller,
    PlayerStateData playerState,
    Track currentTrack,
    bool isPlaying,
    bool isShuffle,
    RepeatMode repeatMode,
  ) {
    return Padding(
      padding: const EdgeInsets.all(MelodiaTokens.spacingXxl),
      child: Row(
        children: [
          // Left: Artwork + Transport
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MelodiaTokens.radiusHero),
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        boxShadow: MelodiaTokens.cardShadow,
                      ),
                      child: currentTrack.thumbnail != null &&
                              currentTrack.thumbnail!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: currentTrack.thumbnail!,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.music_note_rounded,
                              size: 64,
                              color: tokens.textTertiary,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: MelodiaTokens.spacingXl),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        Text(
                          currentTrack.title,
                          style: MelodiaTokens.title2.copyWith(
                            color: tokens.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentTrack.artist,
                          style: MelodiaTokens.headline.copyWith(
                            color: tokens.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: MelodiaTokens.spacingSm),
                    LikeHeartButton(track: currentTrack, size: 28),
                  ],
                ),
                const SizedBox(height: MelodiaTokens.spacingLg),
                SizedBox(
                  width: 400,
                  child: ScrubBar(
                    position: playerState.position,
                    duration: playerState.duration,
                    onSeek: (pos) => controller.seekTo(pos),
                  ),
                ),
                const SizedBox(height: MelodiaTokens.spacingMd),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: tokens.text,
                        size: 36,
                      ),
                      onPressed: () => controller.skipPrevious(),
                    ),
                    const SizedBox(width: MelodiaTokens.spacingMd),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: tokens.text,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: tokens.background,
                          size: 36,
                        ),
                        onPressed: () => controller.togglePlayPause(),
                      ),
                    ),
                    const SizedBox(width: MelodiaTokens.spacingMd),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: tokens.text,
                        size: 36,
                      ),
                      onPressed: () => controller.skipNext(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: MelodiaTokens.spacingXxl),
          // Right: Close button & Queue panel embedded
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: tokens.text),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
                    ),
                    padding: const EdgeInsets.all(MelodiaTokens.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _desktopTab = 0),
                              child: Text(
                                'Playing Next',
                                style: MelodiaTokens.title3.copyWith(
                                  color: _desktopTab == 0 ? tokens.text : tokens.textTertiary,
                                  fontWeight: _desktopTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: MelodiaTokens.spacingLg),
                            GestureDetector(
                              onTap: () => setState(() => _desktopTab = 1),
                              child: Text(
                                'Lyrics',
                                style: MelodiaTokens.title3.copyWith(
                                  color: _desktopTab == 1 ? tokens.text : tokens.textTertiary,
                                  fontWeight: _desktopTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MelodiaTokens.spacingMd),
                        Expanded(
                          child: _desktopTab == 1
                              ? LyricsView(videoId: currentTrack.videoId)
                              : ListView.builder(
                                  itemCount: playerState.queue.queue.length,
                                  itemBuilder: (context, index) {
                                    final track = playerState.queue.queue[index];
                                    final isCurrent = index == playerState.queue.currentIndex;
                                    return ListTile(
                                      leading: Text(
                                        '${index + 1}',
                                        style: MelodiaTokens.body.copyWith(
                                          color: isCurrent ? tokens.accent : tokens.textSecondary,
                                        ),
                                      ),
                                      title: Text(
                                        track.title,
                                        style: MelodiaTokens.body.copyWith(
                                          color: isCurrent ? tokens.accent : tokens.text,
                                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                      subtitle: Text(
                                        track.artist,
                                        style: MelodiaTokens.footnote.copyWith(
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                      onTap: () => controller.playList(playerState.queue.queue, index),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpringCurve extends Curve {
  const SpringCurve({this.damping = 18.0});
  final double damping;

  @override
  double transformInternal(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
  }
}
