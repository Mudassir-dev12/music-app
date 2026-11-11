import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import React, { useMemo } from 'react';
import { PanResponder, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

import { IconButton } from '@/components/IconButton';
import { MarqueeText } from '@/components/MarqueeText';
import { getCurrentTrack } from '@/player/queue';
import { usePlayerStore } from '@/store/player';
import { useTheme } from '@/theme/ThemeProvider';
import { elevation, layoutTokens, radii, spacing, typography, zIndices } from '@/theme/tokens';

export function MiniPlayer() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const store = usePlayerStore();
  const currentTrack = getCurrentTrack(store);

  const swipeUpResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) => g.dy < -16 && Math.abs(g.dy) > Math.abs(g.dx),
        onPanResponderRelease: (_, g) => {
          if (g.dy < -24) {
            store.setNowPlayingOpen(true);
          }
        },
      }),
    [store]
  );

  if (!currentTrack) {
    return null;
  }

  const ratio =
    store.durationSec > 0
      ? Math.min(1, Math.max(0, store.positionSec / store.durationSec))
      : 0;

  return (
    <View
      {...swipeUpResponder.panHandlers}
      style={[
        styles.wrapper,
        elevation.artworkShadow,
        {
          bottom: layoutTokens.tabBarHeight + insets.bottom + spacing.xs,
          borderColor: colors.separator,
        },
      ]}
      testID="mini-player"
    >
      <BlurView intensity={85} tint={colors.blurTint} style={StyleSheet.absoluteFill} />
      <View
        style={[
          styles.progressTrack,
          { backgroundColor: colors.surface2 },
        ]}
      >
        <View
          style={[
            styles.progressFill,
            {
              width: `${Math.round(ratio * 1000) / 10}%`,
              backgroundColor: colors.accent,
            },
          ]}
        />
      </View>

      <View style={styles.content}>
        <Pressable
          onPress={() => store.setNowPlayingOpen(true)}
          accessibilityRole="button"
          accessibilityLabel={`Open Now Playing for ${currentTrack.title}`}
          testID="mini-player-open"
          style={styles.trackPress}
        >
          <View style={[styles.artworkWrap, { backgroundColor: colors.surface2 }]}>
            {currentTrack.thumbnail ? (
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
              text={currentTrack.title}
              style={[typography.subhead, styles.title, { color: colors.text }]}
            />
            <Text style={[typography.caption, { color: colors.textSecondary }]} numberOfLines={1}>
              {currentTrack.artist}
            </Text>
          </View>
        </Pressable>

        <View style={styles.controls}>
          <IconButton
            name={store.isPlaying ? 'pause' : 'play'}
            size={layoutTokens.iconSizeMd}
            onPress={() => {
              void store.togglePlayPause();
            }}
            accessibilityLabel={store.isPlaying ? 'Pause' : 'Play'}
            testID="mini-player-play-pause"
          />
          <IconButton
            name="play-forward"
            size={layoutTokens.iconSizeMd}
            onPress={() => {
              void store.nextTrack(false);
            }}
            accessibilityLabel="Next track"
            testID="mini-player-next"
          />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    position: 'absolute',
    left: spacing.sm,
    right: spacing.sm,
    height: layoutTokens.miniPlayerHeight,
    borderRadius: radii.sheet,
    borderWidth: layoutTokens.hairline,
    overflow: 'hidden',
    zIndex: zIndices.miniPlayer,
  },
  progressTrack: {
    height: layoutTokens.progressLineHeight,
    width: '100%',
  },
  progressFill: {
    height: '100%',
  },
  content: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    gap: spacing.sm,
  },
  trackPress: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  artworkWrap: {
    width: layoutTokens.artMini,
    height: layoutTokens.artMini,
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
  },
  title: {
    fontWeight: '600',
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xxs,
  },
});

