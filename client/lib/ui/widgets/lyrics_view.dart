import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discovery_providers.dart';
import '../../player/lyrics_sync.dart';
import '../../player/player_controller.dart';
import '../../theme/tokens.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveIndex(int index, int totalLines) {
    if (!_scrollController.hasClients || index < 0) return;
    // Estimate scroll offset: approximate 56px per line
    final targetOffset = (index * 56.0 - 150.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final lyricsAsync = ref.watch(lyricsProvider(widget.videoId));
    final playerState = ref.watch(playerControllerProvider);
    final posMs = playerState.position.inMilliseconds;

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || (!lyrics.isSynced && (lyrics.plain == null || lyrics.plain!.trim().isEmpty))) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lyrics_rounded, size: 56, color: tokens.textTertiary),
                const SizedBox(height: MelodiaTokens.spacingMd),
                Text(
                  "Lyrics aren't available for this song.",
                  style: MelodiaTokens.subhead.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          );
        }

        // 1. Synced Lyrics
        if (lyrics.isSynced) {
          final activeIndex = findCurrentLyricIndex(lyrics.synced, posMs);
          if (activeIndex != _lastActiveIndex) {
            _lastActiveIndex = activeIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToActiveIndex(activeIndex, lyrics.synced.length);
            });
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingLg,
              vertical: MelodiaTokens.spacingPage,
            ),
            itemCount: lyrics.synced.length + 1, // +1 for source footer
            itemBuilder: (context, index) {
              if (index == lyrics.synced.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: MelodiaTokens.spacingXxl, bottom: 40),
                  child: Text(
                    lyrics.source != null && lyrics.source!.isNotEmpty
                        ? 'Source: ${lyrics.source}'
                        : 'Lyrics provided by YouTube Music',
                    style: MelodiaTokens.caption.copyWith(color: tokens.textTertiary),
                  ),
                );
              }

              final line = lyrics.synced[index];
              final isActive = index == activeIndex;

              return Semantics(
                button: true,
                label: 'Seek to ${line.text}',
                child: GestureDetector(
                  onTap: () {
                    ref.read(playerControllerProvider.notifier).seekTo(
                          Duration(milliseconds: line.startMs),
                        );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: MelodiaTokens.spacingSm),
                    child: Text(
                      line.text.isNotEmpty ? line.text : '♪',
                      style: (isActive ? MelodiaTokens.title2 : MelodiaTokens.title3).copyWith(
                        color: isActive ? tokens.text : tokens.textTertiary,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        // 2. Plain (unsynced) lyrics
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: MelodiaTokens.spacingLg,
            vertical: MelodiaTokens.spacingPage,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lyrics.plain!,
                style: MelodiaTokens.body.copyWith(
                  color: tokens.text,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: MelodiaTokens.spacingXxl),
              Text(
                lyrics.source != null && lyrics.source!.isNotEmpty
                    ? 'Source: ${lyrics.source}'
                    : 'Lyrics provided by YouTube Music',
                style: MelodiaTokens.caption.copyWith(color: tokens.textTertiary),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          "Couldn't load lyrics.",
          style: MelodiaTokens.subhead.copyWith(color: tokens.textTertiary),
        ),
      ),
    );
  }
}
