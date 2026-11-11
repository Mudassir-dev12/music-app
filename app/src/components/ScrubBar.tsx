import React, { useRef, useState } from 'react';
import {
  type GestureResponderEvent,
  type LayoutChangeEvent,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';
import { formatRemaining, formatTime } from '@/utils/format';

export interface ScrubBarProps {
  positionSec: number;
  durationSec: number;
  onSeek: (seconds: number) => void;
  showLabels?: boolean;
  lightOnDark?: boolean;
  disabled?: boolean;
  testID?: string;
}

export function ScrubBar({
  positionSec,
  durationSec,
  onSeek,
  showLabels = true,
  lightOnDark = false,
  disabled = false,
  testID,
}: ScrubBarProps) {
  const { colors } = useTheme();
  const [dragging, setDragging] = useState(false);
  const [dragRatio, setDragRatio] = useState(0);

  const trackWidthRef = useRef(1);
  const startPageXRef = useRef(0);
  const startRatioRef = useRef(0);
  const dragRatioRef = useRef(0);

  const safeDuration = Number.isFinite(durationSec) && durationSec > 0 ? durationSec : 0;
  const canScrub = !disabled && safeDuration > 0;

  const handleGrant = (evt: GestureResponderEvent) => {
    const x = evt.nativeEvent.locationX;
    const next = Math.min(1, Math.max(0, x / Math.max(1, trackWidthRef.current)));
    startPageXRef.current = evt.nativeEvent.pageX;
    startRatioRef.current = next;
    dragRatioRef.current = next;
    setDragRatio(next);
    setDragging(true);
  };

  const handleMove = (evt: GestureResponderEvent) => {
    const dx = evt.nativeEvent.pageX - startPageXRef.current;
    const next = Math.min(
      1,
      Math.max(0, startRatioRef.current + dx / Math.max(1, trackWidthRef.current))
    );
    dragRatioRef.current = next;
    setDragRatio(next);
  };

  const handleRelease = () => {
    const target = dragRatioRef.current * safeDuration;
    setDragging(false);
    onSeek(target);
  };

  const handleTerminate = () => {
    setDragging(false);
  };

  const liveRatio =
    safeDuration > 0 ? Math.min(1, Math.max(0, positionSec / safeDuration)) : 0;
  const activeRatio = dragging ? dragRatio : liveRatio;
  const displayedPosition = dragging ? activeRatio * safeDuration : positionSec;

  const trackBg = lightOnDark ? colors.overlayLight : colors.surface2;
  const fillBg = lightOnDark ? colors.onAccent : colors.text;
  const labelColor = colors.textSecondary;

  const onLayout = (e: LayoutChangeEvent) => {
    trackWidthRef.current = Math.max(1, e.nativeEvent.layout.width);
  };

  const trackHeight = dragging
    ? layoutTokens.scrubberTrackActiveHeight
    : layoutTokens.scrubberTrackHeight;

  return (
    <View style={styles.wrapper} testID={testID}>
      <View
        onLayout={onLayout}
        onStartShouldSetResponder={() => canScrub}
        onMoveShouldSetResponder={() => canScrub}
        onResponderGrant={handleGrant}
        onResponderMove={handleMove}
        onResponderRelease={handleRelease}
        onResponderTerminate={handleTerminate}
        accessibilityRole="adjustable"
        accessibilityLabel="Playback position"
        testID={testID ? `${testID}-track` : 'scrub-bar-track'}
        style={styles.touchArea}
      >
        <View
          style={[
            styles.track,
            {
              height: trackHeight,
              backgroundColor: trackBg,
            },
          ]}
        >
          <View
            style={[
              styles.fill,
              {
                width: `${Math.round(activeRatio * 1000) / 10}%`,
                backgroundColor: fillBg,
              },
            ]}
          />
        </View>
      </View>

      {showLabels ? (
        <View style={styles.labels}>
          <Text
            style={[typography.caption, styles.timeText, { color: labelColor }]}
            testID={testID ? `${testID}-elapsed` : 'scrub-elapsed'}
          >
            {formatTime(displayedPosition)}
          </Text>
          <Text
            style={[typography.caption, styles.timeText, { color: labelColor }]}
            testID={testID ? `${testID}-remaining` : 'scrub-remaining'}
          >
            {formatRemaining(displayedPosition, safeDuration)}
          </Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    width: '100%',
    gap: spacing.xxs,
  },
  touchArea: {
    height: spacing.lg,
    justifyContent: 'center',
  },
  track: {
    width: '100%',
    borderRadius: radii.pill,
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: radii.pill,
  },
  labels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  timeText: {
    fontVariant: ['tabular-nums'],
  },
});
