import React, { useEffect, useState } from 'react';
import { type LayoutChangeEvent, StyleSheet, Text, type TextStyle, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';

import { useTheme } from '@/theme/ThemeProvider';
import { spacing } from '@/theme/tokens';

export interface MarqueeTextProps {
  text: string;
  style?: TextStyle | TextStyle[];
  testID?: string;
}

export function MarqueeText({ text, style, testID }: MarqueeTextProps) {
  const { reduceMotion } = useTheme();
  const [containerWidth, setContainerWidth] = useState(0);
  const [textWidth, setTextWidth] = useState(0);
  const translateX = useSharedValue(0);

  const shouldScroll = !reduceMotion && containerWidth > 0 && textWidth > containerWidth + spacing.xxs;
  const overflow = Math.max(0, textWidth - containerWidth + spacing.md);

  useEffect(() => {
    translateX.value = 0;
    if (!shouldScroll || overflow <= 0) return;

    const travelMs = Math.max(2500, Math.round(overflow * 35));
    translateX.value = withRepeat(
      withSequence(
        withDelay(1500, withTiming(-overflow, { duration: travelMs, easing: Easing.linear })),
        withDelay(1200, withTiming(0, { duration: 400, easing: Easing.out(Easing.quad) }))
      ),
      -1,
      false
    );
  }, [overflow, shouldScroll, text, translateX]);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  const onContainerLayout = (e: LayoutChangeEvent) => {
    setContainerWidth(e.nativeEvent.layout.width);
  };

  return (
    <View style={styles.container} onLayout={onContainerLayout} testID={testID}>
      {/* Hidden measurement text at unconstrained width */}
      <Text
        style={[style, styles.measure]}
        onLayout={(e) => setTextWidth(e.nativeEvent.layout.width)}
      >
        {text}
      </Text>
      <Animated.View style={[styles.track, animStyle]}>
        <Text style={style} numberOfLines={1}>
          {text}
        </Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
    position: 'relative',
  },
  track: {
    flexDirection: 'row',
  },
  measure: {
    position: 'absolute',
    opacity: 0,
    left: 0,
    top: 0,
    width: 9999,
  },
});

