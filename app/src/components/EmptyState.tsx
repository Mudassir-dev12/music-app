import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { type IoniconName } from '@/components/IconButton';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, spacing, typography } from '@/theme/tokens';

export interface EmptyStateProps {
  icon: IoniconName;
  title: string;
  message: string;
  testID?: string;
}

export function EmptyState({ icon, title, message, testID }: EmptyStateProps) {
  const { colors } = useTheme();

  return (
    <View style={styles.container} testID={testID} accessibilityLabel={`${title}. ${message}`}>
      <Ionicons name={icon} size={layoutTokens.iconSizeXl} color={colors.textTertiary} />
      <Text style={[typography.title3, styles.title, { color: colors.text }]}>{title}</Text>
      <Text style={[typography.subhead, styles.message, { color: colors.textSecondary }]}>
        {message}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.xxxl,
    paddingHorizontal: spacing.xl,
    gap: spacing.sm,
  },
  title: {
    textAlign: 'center',
  },
  message: {
    textAlign: 'center',
    maxWidth: layoutTokens.maxFormWidth,
  },
});
