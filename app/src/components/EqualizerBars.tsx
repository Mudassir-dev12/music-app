import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';

import { useTheme } from '@/theme/ThemeProvider';
import { radii, spacing } from '@/theme/tokens';

export interface EqualizerBarsProps {
  playing: boolean;
  color?: string;
  testID?: string;
}

function Bar({
  playing,
  duration,
  initialHeight,
  color,
  reduceMotion,
}: {
  playing: boolean;
  duration: number;
  initialHeight: number;
  color: string;
  reduceMotion: boolean;
}) {
  const height = useSharedValue(initialHeight);

  useEffect(() => {
    if (!playing || reduceMotion) {
      height.value = initialHeight;
      return;
    }
    height.value = withRepeat(
      withSequence(
        withTiming(spacing.md, { duration }),
        withTiming(spacing.xxs, { duration })
      ),
      -1,
      true
    );
  }, [duration, height, initialHeight, playing, reduceMotion]);

  const animStyle = useAnimatedStyle(() => ({
    height: height.value,
  }));

  return <Animated.View style={[styles.bar, { backgroundColor: color }, animStyle]} />;
}

export function EqualizerBars({ playing, color, testID }: EqualizerBarsProps) {
  const { colors, reduceMotion } = useTheme();
  const barColor = color ?? colors.accent;

  return (
    <View
      style={styles.container}
      testID={testID}
      accessibilityLabel={playing ? 'Now playing' : 'Paused'}
    >
      <Bar playing={playing} duration={360} initialHeight={spacing.xs} color={barColor} reduceMotion={reduceMotion} />
      <Bar playing={playing} duration={280} initialHeight={spacing.sm} color={barColor} reduceMotion={reduceMotion} />
      <Bar playing={playing} duration={420} initialHeight={spacing.xxs} color={barColor} reduceMotion={reduceMotion} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: spacing.xxs / 2,
    height: spacing.md,
    width: spacing.md,
    justifyContent: 'center',
  },
  bar: {
    width: spacing.xxs - 1,
    borderRadius: radii.pill,
  },
});
