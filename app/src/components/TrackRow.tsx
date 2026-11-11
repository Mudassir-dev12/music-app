import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';

import { type Track } from '@/api/types';
import { EqualizerBars } from '@/components/EqualizerBars';
import { IconButton } from '@/components/IconButton';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';
import { formatTime } from '@/utils/format';

export interface TrackRowProps {
  track: Track;
  isCurrent?: boolean;
  isPlaying?: boolean;
  onPress: () => void;
  onMorePress?: () => void;
  showSeparator?: boolean;
  testID?: string;
}

export function TrackRow({
  track,
  isCurrent = false,
  isPlaying = false,
  onPress,
  onMorePress,
  showSeparator = true,
  testID,
}: TrackRowProps) {
  const { colors } = useTheme();

  return (
    <Pressable
      onPress={onPress}
      onLongPress={onMorePress}
      accessibilityRole="button"
      accessibilityLabel={`${track.title} by ${track.artist}`}
      testID={testID}
      style={({ pressed }) => [
        styles.row,
        { backgroundColor: pressed ? colors.surface : 'transparent' },
      ]}
    >
      <View style={[styles.artworkWrap, { backgroundColor: colors.surface2 }]}>
        {track.thumbnail ? (
          <Image
            source={{ uri: track.thumbnail }}
            style={styles.artwork}
            contentFit="cover"
            transition={150}
          />
        ) : (
          <Ionicons name="musical-note" size={layoutTokens.iconSizeMd} color={colors.textTertiary} />
        )}
        {isCurrent ? (
          <View style={[StyleSheet.absoluteFill, styles.eqOverlay, { backgroundColor: colors.overlayMedium }]}>
            <EqualizerBars playing={isPlaying} color={colors.onAccent} />
          </View>
        ) : null}
      </View>

      <View
        style={[
          styles.metaWrap,
          showSeparator
            ? { borderBottomWidth: layoutTokens.hairline, borderBottomColor: colors.separator }
            : undefined,
        ]}
      >
        <View style={styles.textCol}>
          <View style={styles.titleRow}>
            <Text
              style={[
                typography.body,
                styles.title,
                { color: isCurrent ? colors.accent : colors.text },
              ]}
              numberOfLines={1}
            >
              {track.title}
            </Text>
            {track.is_explicit ? (
              <View style={[styles.explicitBadge, { backgroundColor: colors.surface2 }]}>
                <Text style={[typography.caption, { color: colors.textSecondary }]}>E</Text>
              </View>
            ) : null}
          </View>
          <Text style={[typography.footnote, { color: colors.textSecondary }]} numberOfLines={1}>
            {track.artist}
            {track.album ? ` · ${track.album}` : ''}
          </Text>
        </View>

        <View style={styles.rightCol}>
          {track.duration_seconds ? (
            <Text style={[typography.footnote, styles.duration, { color: colors.textTertiary }]}>
              {formatTime(track.duration_seconds)}
            </Text>
          ) : null}
          {onMorePress ? (
            <IconButton
              name="ellipsis-horizontal"
              size={layoutTokens.iconSizeSm + spacing.xxs}
              color={colors.textSecondary}
              onPress={onMorePress}
              accessibilityLabel={`More options for ${track.title}`}
              testID={testID ? `${testID}-more` : undefined}
            />
          ) : null}
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: radii.card,
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
  eqOverlay: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  metaWrap: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.xs,
    gap: spacing.sm,
  },
  textCol: {
    flex: 1,
    gap: spacing.xxs / 2,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  title: {
    flexShrink: 1,
  },
  explicitBadge: {
    paddingHorizontal: spacing.xxs,
    borderRadius: radii.artSmall / 2,
  },
  rightCol: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  duration: {
    fontVariant: ['tabular-nums'],
  },
});
