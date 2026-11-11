import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/theme/ThemeProvider';
import { spacing, typography } from '@/theme/tokens';

export interface SectionHeaderProps {
  title: string;
  onSeeAll?: () => void;
  seeAllLabel?: string;
  testID?: string;
}

export function SectionHeader({
  title,
  onSeeAll,
  seeAllLabel = 'See All',
  testID,
}: SectionHeaderProps) {
  const { colors } = useTheme();

  return (
    <View style={styles.row} testID={testID}>
      <Text style={[typography.title2, { color: colors.text }]} accessibilityRole="header">
        {title}
      </Text>
      {onSeeAll ? (
        <Pressable onPress={onSeeAll} accessibilityRole="button" accessibilityLabel={seeAllLabel}>
          <Text style={[typography.callout, { color: colors.accent }]}>{seeAllLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
});

