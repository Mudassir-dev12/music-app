import React, { useEffect, useRef } from 'react';
import {
  type GestureResponderEvent,
  type LayoutChangeEvent,
  Platform,
  StyleSheet,
  View,
} from 'react-native';

import { IconButton } from '@/components/IconButton';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing } from '@/theme/tokens';

export interface VolumeSliderProps {
  volume: number;
  onChange: (volume: number) => void;
  lightOnDark?: boolean;
  testID?: string;
}

export function VolumeSlider({
  volume,
  onChange,
  lightOnDark = false,
  testID,
}: VolumeSliderProps) {
  const { colors } = useTheme();
  const trackWidthRef = useRef(1);
  const startPageXRef = useRef(0);
  const startVolRef = useRef(volume);
  const lastNonZeroRef = useRef(volume > 0 ? volume : 0.8);

  useEffect(() => {
    if (volume > 0) {
      lastNonZeroRef.current = volume;
    }
  }, [volume]);

  const handleGrant = (evt: GestureResponderEvent) => {
    const next = Math.min(
      1,
      Math.max(0, evt.nativeEvent.locationX / Math.max(1, trackWidthRef.current))
    );
    startPageXRef.current = evt.nativeEvent.pageX;
    startVolRef.current = next;
    onChange(next);
  };

  const handleMove = (evt: GestureResponderEvent) => {
    const dx = evt.nativeEvent.pageX - startPageXRef.current;
    const next = Math.min(
      1,
      Math.max(0, startVolRef.current + dx / Math.max(1, trackWidthRef.current))
    );
    onChange(next);
  };

  // Native devices use hardware volume buttons
  if (Platform.OS !== 'web') {
    return null;
  }

  const iconName =
    volume === 0 ? 'volume-mute' : volume < 0.5 ? 'volume-low' : 'volume-high';
  const trackBg = lightOnDark ? colors.overlayLight : colors.surface2;
  const fillBg = lightOnDark ? colors.onAccent : colors.textSecondary;

  return (
    <View style={styles.row} testID={testID}>
      <IconButton
        name={iconName}
        size={layoutTokens.iconSizeSm + spacing.xxs}
        color={lightOnDark ? colors.onAccent : colors.textSecondary}
        onPress={() => onChange(volume > 0 ? 0 : lastNonZeroRef.current)}
        accessibilityLabel={volume > 0 ? 'Mute volume' : 'Unmute volume'}
        testID={testID ? `${testID}-mute` : undefined}
      />
      <View
        style={styles.touchArea}
        onLayout={(e: LayoutChangeEvent) => {
          trackWidthRef.current = Math.max(1, e.nativeEvent.layout.width);
        }}
        onStartShouldSetResponder={() => true}
        onMoveShouldSetResponder={() => true}
        onResponderGrant={handleGrant}
        onResponderMove={handleMove}
        accessibilityRole="adjustable"
        accessibilityLabel="Volume"
      >
        <View style={[styles.track, { backgroundColor: trackBg }]}>
          <View
            style={[
              styles.fill,
              { width: `${Math.round(volume * 100)}%`, backgroundColor: fillBg },
            ]}
          />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    flex: 1,
    minWidth: spacing.xxxl * 3,
    maxWidth: spacing.xxxl * 4.5,
  },
  touchArea: {
    flex: 1,
    height: spacing.lg,
    justifyContent: 'center',
  },
  track: {
    height: layoutTokens.scrubberTrackHeight,
    borderRadius: radii.pill,
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: radii.pill,
  },
});
