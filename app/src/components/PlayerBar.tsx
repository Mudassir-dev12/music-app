import { Image } from 'expo-image';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { IconButton } from '@/components/IconButton';
import { MarqueeText } from '@/components/MarqueeText';
import { ScrubBar } from '@/components/ScrubBar';
import { VolumeSlider } from '@/components/VolumeSlider';
import { getCurrentTrack } from '@/player/queue';
import { usePlayerStore } from '@/store/player';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography, zIndices } from '@/theme/tokens';

export function PlayerBar() {
  const { colors } = useTheme();
  const store = usePlayerStore();
  const currentTrack = getCurrentTrack(store);
  const repeatIcon = store.repeat === 'off' ? 'repeat-outline' : 'repeat';

  return (
    <View
      style={[
        styles.bar,
        {
          backgroundColor: colors.surface,
          borderTopColor: colors.separator,
        },
      ]}
      testID="desktop-player-bar"
    >
      {/* Left: Artwork + Title/Artist */}
      <Pressable
        disabled={!currentTrack}
        onPress={() => store.setNowPlayingOpen(true)}
        accessibilityRole="button"
        accessibilityLabel={currentTrack ? `Open Now Playing for ${currentTrack.title}` : 'No track loaded'}
        testID="player-bar-track-info"
        style={styles.leftCol}
      >
        <View style={[styles.artworkWrap, { backgroundColor: colors.surface2 }]}>
          {currentTrack?.thumbnail ? (
            <Image
              source={{ uri: currentTrack.thumbnail }}
              style={styles.artwork}
              contentFit="cover"
            />
          ) : (
            <Ionicons
              name="musical-note"
              size={layoutTokens.iconSizeMd}
              color={colors.textTertiary}
            />
          )}
        </View>
        <View style={styles.meta}>
          <MarqueeText
            text={currentTrack ? currentTrack.title : 'Not Playing'}
            style={[typography.subhead, styles.title, { color: colors.text }]}
          />
          <Text style={[typography.caption, { color: colors.textSecondary }]} numberOfLines={1}>
            {currentTrack ? currentTrack.artist : 'Select a song from Search'}
          </Text>
        </View>
      </Pressable>

      {/* Center: Transport + Scrubber */}
      <View style={styles.centerCol}>
        <View style={styles.transportRow}>
          <IconButton
            name="shuffle"
            size={layoutTokens.iconSizeSm + spacing.xxs}
            color={store.shuffle ? colors.accent : colors.textSecondary}
            onPress={store.toggleShuffle}
            accessibilityLabel="Toggle shuffle"
            testID="player-bar-shuffle"
          />
          <IconButton
            name="play-back"
            size={layoutTokens.iconSizeMd}
            disabled={!currentTrack}
            onPress={() => {
              void store.previousTrack();
            }}
            accessibilityLabel="Previous track"
            testID="player-bar-prev"
          />
          <IconButton
            name={store.isPlaying ? 'pause-circle' : 'play-circle'}
            size={layoutTokens.iconSizeLg + spacing.sm}
            color={colors.text}
            disabled={!currentTrack}
            onPress={() => {
              void store.togglePlayPause();
            }}
            accessibilityLabel={store.isPlaying ? 'Pause' : 'Play'}
            testID="player-bar-play-pause"
          />
          <IconButton
            name="play-forward"
            size={layoutTokens.iconSizeMd}
            disabled={!currentTrack}
            onPress={() => {
              void store.nextTrack(false);
            }}
            accessibilityLabel="Next track"
            testID="player-bar-next"
          />
          <View style={styles.repeatWrap}>
            <IconButton
              name={repeatIcon}
              size={layoutTokens.iconSizeSm + spacing.xxs}
              color={store.repeat !== 'off' ? colors.accent : colors.textSecondary}
              onPress={store.cycleRepeat}
              accessibilityLabel={`Repeat mode: ${store.repeat}`}
              testID="player-bar-repeat"
            />
            {store.repeat === 'one' ? (
              <Text style={[typography.caption, styles.repeatOneBadge, { color: colors.accent }]}>
                1
              </Text>
            ) : null}
          </View>
        </View>

        <ScrubBar
          positionSec={store.positionSec}
          durationSec={store.durationSec}
          onSeek={(sec) => {
            void store.seek(sec);
          }}
          disabled={!currentTrack}
          testID="player-bar-scrubber"
        />
      </View>

      {/* Right: Volume + Queue */}
      <View style={styles.rightCol}>
        <VolumeSlider
          volume={store.volume}
          onChange={store.setVolume}
          testID="player-bar-volume"
        />
        <IconButton
          name="list"
          size={layoutTokens.iconSizeMd}
          color={store.queueOpen ? colors.accent : colors.textSecondary}
          onPress={() => store.setQueueOpen(!store.queueOpen)}
          accessibilityLabel="Toggle queue"
          testID="player-bar-queue"
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    height: layoutTokens.playerBarHeight,
    borderTopWidth: layoutTokens.hairline,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    gap: spacing.lg,
    zIndex: zIndices.playerBar,
  },
  leftCol: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    minWidth: 0,
  },
  artworkWrap: {
    width: layoutTokens.artRow,
    height: layoutTokens.artRow,
    borderRadius: radii.artSmall,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  artwork: {
    width: '100%',
    height: '100%',
  },
  meta: {
    flex: 1,
    gap: spacing.xxs / 2,
    minWidth: 0,
  },
  title: {
    fontWeight: '600',
  },
  centerCol: {
    flex: 2,
    maxWidth: layoutTokens.maxFormWidth + spacing.xxxl * 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  transportRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  repeatWrap: {
    position: 'relative',
  },
  repeatOneBadge: {
    position: 'absolute',
    right: spacing.xxs,
    top: spacing.xxs / 2,
    fontWeight: '700',
  },
  rightCol: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: spacing.sm,
  },
});

