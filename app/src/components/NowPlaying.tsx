import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import React, { useEffect, useMemo, useState } from 'react';
import {
  Modal,
  PanResponder,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

import { IconButton } from '@/components/IconButton';
import { MarqueeText } from '@/components/MarqueeText';
import { QueueContent } from '@/components/QueuePanel';
import { ScrubBar } from '@/components/ScrubBar';
import { VolumeSlider } from '@/components/VolumeSlider';
import { useLayout } from '@/hooks/useLayout';
import { getCurrentTrack } from '@/player/queue';
import { usePlayerStore } from '@/store/player';
import { useTheme } from '@/theme/ThemeProvider';
import { elevation, layoutTokens, motion, radii, spacing, typography } from '@/theme/tokens';

const COMING_SOON_ITEMS = [
  'Add to playlist',
  'Like',
  'Download',
  'Go to artist',
] as const;

export function NowPlaying() {
  const { colors, reduceMotion } = useTheme();
  const { width, isDesktop } = useLayout();
  const store = usePlayerStore();
  const currentTrack = getCurrentTrack(store);
  const [moreOpen, setMoreOpen] = useState(false);

  const artScale = useSharedValue(
    store.isPlaying ? motion.artPlayingScale : motion.artPausedScale
  );
  const bgOpacity = useSharedValue(1);

  useEffect(() => {
    const target = store.isPlaying ? motion.artPlayingScale : motion.artPausedScale;
    artScale.value = reduceMotion ? target : withSpring(target, motion.spring);
  }, [artScale, reduceMotion, store.isPlaying]);

  useEffect(() => {
    if (reduceMotion) return;
    bgOpacity.value = 0.7;
    bgOpacity.value = withTiming(1, { duration: motion.crossFadeMs });
  }, [bgOpacity, currentTrack?.video_id, reduceMotion]);

  const artworkAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: artScale.value }],
  }));

  const bgAnimStyle = useAnimatedStyle(() => ({
    opacity: bgOpacity.value,
  }));

  const dragDismissResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) =>
          !isDesktop && g.dy > 20 && Math.abs(g.dy) > Math.abs(g.dx),
        onPanResponderRelease: (_, g) => {
          if (g.dy > 60) {
            store.setNowPlayingOpen(false);
          }
        },
      }),
    [isDesktop, store]
  );

  if (!store.nowPlayingOpen || !currentTrack) {
    return null;
  }

  const artSize = isDesktop
    ? Math.min(layoutTokens.artHeroMax, Math.floor(width * 0.36))
    : Math.min(layoutTokens.artHeroMax, Math.max(layoutTokens.artCard, width - layoutTokens.artHeroMargin));

  const repeatIcon = store.repeat === 'off' ? 'repeat-outline' : 'repeat';

  return (
    <Modal
      visible={store.nowPlayingOpen}
      animationType={reduceMotion ? 'none' : 'slide'}
      presentationStyle="fullScreen"
      onRequestClose={() => store.setNowPlayingOpen(false)}
      testID="now-playing-modal"
    >
      <View style={[styles.root, { backgroundColor: colors.background }]}>
        {/* Blurred artwork background (never reads pixels) */}
        {currentTrack.thumbnail ? (
          <Animated.View style={[StyleSheet.absoluteFill, bgAnimStyle]}>
            <Image
              source={{ uri: currentTrack.thumbnail }}
              style={styles.backdropImage}
              contentFit="cover"
            />
          </Animated.View>
        ) : null}
        <BlurView intensity={95} tint="dark" style={StyleSheet.absoluteFill} />
        <LinearGradient
          colors={[colors.overlayMedium, colors.overlayDark]}
          style={StyleSheet.absoluteFill}
        />

        <SafeAreaView style={styles.safe} {...dragDismissResponder.panHandlers}>
          {/* Header grabber & close chevron */}
          <View style={styles.header}>
            <View style={styles.headerSpacer} />
            <View style={[styles.grabber, { backgroundColor: colors.overlayLight }]} />
            <IconButton
              name="chevron-down"
              size={layoutTokens.iconSizeLg}
              color={colors.onAccent}
              onPress={() => store.setNowPlayingOpen(false)}
              accessibilityLabel="Close Now Playing"
              testID="now-playing-close"
            />
          </View>

          <View style={[styles.body, isDesktop ? styles.bodyDesktop : undefined]}>
            <View style={styles.playerCol}>
              {/* Artwork */}
              <View style={styles.artContainer}>
                <Animated.View
                  testID="now-playing-artwork-container"
                  style={[
                    styles.artworkCard,
                    elevation.artworkShadow,
                    {
                      width: artSize,
                      height: artSize,
                      backgroundColor: colors.surface2,
                    },
                    artworkAnimStyle,
                  ]}
                >
                  {currentTrack.thumbnail ? (
                    <Image
                      source={{ uri: currentTrack.thumbnail }}
                      style={styles.artworkImage}
                      contentFit="cover"
                      transition={motion.crossFadeMs}
                    />
                  ) : (
                    <Ionicons
                      name="musical-note"
                      size={layoutTokens.playButtonSize}
                      color={colors.textTertiary}
                    />
                  )}
                </Animated.View>
              </View>

              {/* Title + Artist + More button */}
              <View style={styles.metaRow}>
                <View style={styles.metaText}>
                  <MarqueeText
                    text={currentTrack.title}
                    style={[typography.title2, { color: colors.onAccent }]}
                    testID="now-playing-title"
                  />
                  <Text
                    style={[typography.callout, { color: colors.accent }]}
                    numberOfLines={1}
                    testID="now-playing-artist"
                  >
                    {currentTrack.artist}
                  </Text>
                </View>

                <IconButton
                  name="ellipsis-horizontal"
                  color={colors.onAccent}
                  onPress={() => setMoreOpen((v) => !v)}
                  accessibilityLabel="More track options"
                  testID="now-playing-more"
                />
              </View>

              {moreOpen ? (
                <View
                  style={[
                    styles.moreMenu,
                    { backgroundColor: colors.surface, borderColor: colors.separator },
                  ]}
                  testID="now-playing-more-menu"
                >
                  <Text style={[typography.caption, { color: colors.textSecondary }]}>
                    Coming soon
                  </Text>
                  {COMING_SOON_ITEMS.map((item) => (
                    <View key={item} style={styles.moreItem}>
                      <Text style={[typography.subhead, { color: colors.textTertiary }]}>
                        {item}
                      </Text>
                    </View>
                  ))}
                </View>
              ) : null}

              {/* Scrubber */}
              <ScrubBar
                positionSec={store.positionSec}
                durationSec={store.durationSec}
                onSeek={(sec) => {
                  void store.seek(sec);
                }}
                lightOnDark
                testID="now-playing-scrubber"
              />

              {/* Transport */}
              <View style={styles.transportRow}>
                <IconButton
                  name="play-back"
                  size={layoutTokens.iconSizeXl - spacing.sm}
                  color={colors.onAccent}
                  onPress={() => {
                    void store.previousTrack();
                  }}
                  accessibilityLabel="Previous track"
                  testID="now-playing-prev"
                />
                <Pressable
                  onPress={() => {
                    void store.togglePlayPause();
                  }}
                  accessibilityRole="button"
                  accessibilityLabel={store.isPlaying ? 'Pause' : 'Play'}
                  testID="now-playing-play-pause"
                  style={({ pressed }) => [
                    styles.playButton,
                    { opacity: pressed ? 0.72 : 1 },
                  ]}
                >
                  <Ionicons
                    name={store.isPlaying ? 'pause' : 'play'}
                    size={layoutTokens.iconSizeXl}
                    color={colors.onAccent}
                  />
                </Pressable>
                <IconButton
                  name="play-forward"
                  size={layoutTokens.iconSizeXl - spacing.sm}
                  color={colors.onAccent}
                  onPress={() => {
                    void store.nextTrack(false);
                  }}
                  accessibilityLabel="Next track"
                  testID="now-playing-next"
                />
              </View>

              {/* Volume (web only) */}
              {Platform.OS === 'web' ? (
                <View style={styles.volumeRow}>
                  <VolumeSlider
                    volume={store.volume}
                    onChange={store.setVolume}
                    lightOnDark
                    testID="now-playing-volume"
                  />
                </View>
              ) : null}

              {/* Bottom row: Lyrics (disabled), Shuffle, Repeat, Queue */}
              <View style={styles.bottomRow}>
                <IconButton
                  name="chatbubble-ellipses-outline"
                  color={colors.onAccent}
                  disabled
                  onPress={() => {}}
                  accessibilityLabel="Lyrics coming in Phase 4"
                  testID="now-playing-lyrics"
                />
                <IconButton
                  name="shuffle"
                  color={store.shuffle ? colors.accent : colors.onAccent}
                  onPress={store.toggleShuffle}
                  accessibilityLabel="Toggle shuffle"
                  testID="now-playing-shuffle"
                />
                <View style={styles.repeatWrap}>
                  <IconButton
                    name={repeatIcon}
                    color={store.repeat !== 'off' ? colors.accent : colors.onAccent}
                    onPress={store.cycleRepeat}
                    accessibilityLabel={`Repeat mode: ${store.repeat}`}
                    testID="now-playing-repeat"
                  />
                  {store.repeat === 'one' ? (
                    <Text style={[typography.caption, styles.repeatOneBadge, { color: colors.accent }]}>
                      1
                    </Text>
                  ) : null}
                </View>
                {!isDesktop ? (
                  <IconButton
                    name="list"
                    color={colors.onAccent}
                    onPress={() => {
                      store.setNowPlayingOpen(false);
                      store.setQueueOpen(true);
                    }}
                    accessibilityLabel="Open queue"
                    testID="now-playing-queue-button"
                  />
                ) : null}
              </View>
            </View>

            {isDesktop ? (
              <View
                style={[
                  styles.desktopQueueCol,
                  {
                    backgroundColor: colors.overlayMedium,
                    borderColor: colors.separator,
                  },
                ]}
              >
                <QueueContent embedded />
              </View>
            ) : null}
          </View>
        </SafeAreaView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  backdropImage: {
    width: '100%',
    height: '100%',
    transform: [{ scale: 1.6 }],
  },
  safe: {
    flex: 1,
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.lg,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.xs,
  },
  headerSpacer: {
    width: layoutTokens.artMini,
  },
  grabber: {
    width: layoutTokens.grabberWidth,
    height: layoutTokens.grabberHeight,
    borderRadius: radii.pill,
  },
  body: {
    flex: 1,
    justifyContent: 'space-between',
    gap: spacing.lg,
  },
  bodyDesktop: {
    flexDirection: 'row',
    alignItems: 'stretch',
    maxWidth: layoutTokens.maxModalWidth + spacing.xxxl * 4,
    width: '100%',
    alignSelf: 'center',
    gap: spacing.xxl,
  },
  playerCol: {
    flex: 1,
    justifyContent: 'center',
    gap: spacing.md,
  },
  desktopQueueCol: {
    flex: 1,
    borderRadius: radii.sheet,
    borderWidth: layoutTokens.hairline,
    overflow: 'hidden',
  },
  artContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: spacing.xs,
  },
  artworkCard: {
    borderRadius: radii.artHero,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  artworkImage: {
    width: '100%',
    height: '100%',
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.md,
  },
  metaText: {
    flex: 1,
    gap: spacing.xxs / 2,
  },
  moreMenu: {
    borderRadius: radii.card,
    borderWidth: layoutTokens.hairline,
    padding: spacing.sm,
    gap: spacing.xs,
  },
  moreItem: {
    paddingVertical: spacing.xxs,
  },
  transportRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-evenly',
    paddingVertical: spacing.xs,
  },
  playButton: {
    width: layoutTokens.playButtonSize,
    height: layoutTokens.playButtonSize,
    alignItems: 'center',
    justifyContent: 'center',
  },
  volumeRow: {
    alignItems: 'center',
  },
  bottomRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
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
});

