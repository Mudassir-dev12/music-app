import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { PillButton } from '@/components/PillButton';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, spacing, typography } from '@/theme/tokens';

export interface ErrorStateProps {
  message: string;
  onRetry?: () => void;
  retryLabel?: string;
  testID?: string;
}

export function ErrorState({
  message,
  onRetry,
  retryLabel = 'Try Again',
  testID,
}: ErrorStateProps) {
  const { colors } = useTheme();

  return (
    <View style={styles.container} testID={testID} accessibilityRole="alert">
      <Ionicons name="alert-circle-outline" size={layoutTokens.iconSizeXl} color={colors.destructive} />
      <Text style={[typography.subhead, styles.message, { color: colors.textSecondary }]}>
        {message}
      </Text>
      {onRetry ? (
        <PillButton
          label={retryLabel}
          icon="refresh"
          variant="surface"
          onPress={onRetry}
          testID={testID ? `${testID}-retry` : 'error-retry-button'}
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.xxxl,
    paddingHorizontal: spacing.xl,
    gap: spacing.md,
  },
  message: {
    textAlign: 'center',
    maxWidth: layoutTokens.maxFormWidth,
  },
});

