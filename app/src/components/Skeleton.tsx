import React, { useEffect } from 'react';
import { StyleSheet, View, type DimensionValue, type StyleProp, type ViewStyle } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';

import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing } from '@/theme/tokens';

export interface SkeletonProps {
  width?: DimensionValue;
  height: number;
  borderRadius?: number;
  style?: StyleProp<ViewStyle>;
  testID?: string;
}

export function Skeleton({
  width = '100%',
  height,
  borderRadius = radii.card,
  style,
  testID,
}: SkeletonProps) {
  const { colors, reduceMotion } = useTheme();
  const opacity = useSharedValue(0.5);

  useEffect(() => {
    if (reduceMotion) {
      opacity.value = 0.65;
      return;
    }
    opacity.value = withRepeat(
      withSequence(withTiming(0.85, { duration: 700 }), withTiming(0.4, { duration: 700 })),
      -1,
      true
    );
  }, [opacity, reduceMotion]);

  const animStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      testID={testID}
      style={[
        { width, height, borderRadius, backgroundColor: colors.surface2 },
        animStyle,
        style,
      ]}
    />
  );
}

export function TrackRowSkeleton() {
  return (
    <View style={styles.row}>
      <Skeleton width={layoutTokens.artRow} height={layoutTokens.artRow} borderRadius={radii.artSmall} />
      <View style={styles.meta}>
        <Skeleton width="65%" height={spacing.md} />
        <Skeleton width="40%" height={spacing.sm} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.xs,
  },
  meta: {
    flex: 1,
    gap: spacing.xs,
  },
});
