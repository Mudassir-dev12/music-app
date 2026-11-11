import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';

import { useLayout } from '@/hooks/useLayout';
import { useTheme } from '@/theme/ThemeProvider';
import { elevation, layoutTokens, radii, spacing, typography } from '@/theme/tokens';

export interface AlbumCardProps {
  title: string;
  subtitle: string;
  artworkUrl?: string | null;
  onPress: () => void;
  testID?: string;
}

export function AlbumCard({
  title,
  subtitle,
  artworkUrl,
  onPress,
  testID,
}: AlbumCardProps) {
  const { colors } = useTheme();
  const { isPhone } = useLayout();
  const cardSize = isPhone ? layoutTokens.artCard : layoutTokens.artCard + spacing.xxl;

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`${title} by ${subtitle}`}
      testID={testID}
      style={({ pressed }) => [
        styles.container,
        { width: cardSize, opacity: pressed ? 0.78 : 1 },
      ]}
    >
      <View
        style={[
          styles.artWrap,
          elevation.artworkShadow,
          {
            width: cardSize,
            height: cardSize,
            backgroundColor: colors.surface2,
          },
        ]}
      >
        {artworkUrl ? (
          <Image
            source={{ uri: artworkUrl }}
            style={styles.art}
            contentFit="cover"
            transition={200}
          />
        ) : (
          <Ionicons name="musical-note" size={layoutTokens.iconSizeXl} color={colors.textTertiary} />
        )}
      </View>
      <Text style={[typography.subhead, styles.title, { color: colors.text }]} numberOfLines={1}>
        {title}
      </Text>
      <Text style={[typography.footnote, { color: colors.textSecondary }]} numberOfLines={1}>
        {subtitle}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: spacing.xxs,
  },
  artWrap: {
    borderRadius: radii.card,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.xxs,
  },
  art: {
    width: '100%',
    height: '100%',
  },
  title: {
    fontWeight: '600',
  },
});
