import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

import { useToastStore } from '@/store/toast';
import { useTheme } from '@/theme/ThemeProvider';
import { elevation, layoutTokens, radii, spacing, typography, zIndices } from '@/theme/tokens';

export function Toast() {
  const { current, hide } = useToastStore();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();

  if (!current) return null;

  const iconName =
    current.tone === 'error'
      ? 'alert-circle'
      : current.tone === 'success'
        ? 'checkmark-circle'
        : 'information-circle';
  const iconColor =
    current.tone === 'error' ? colors.destructive : colors.accent;

  return (
    <View
      pointerEvents="box-none"
      style={[
        styles.wrapper,
        { top: Math.max(insets.top + spacing.xs, spacing.md) },
      ]}
    >
      <Pressable
        onPress={hide}
        accessibilityRole="alert"
        accessibilityLabel={current.message}
        testID="toast-banner"
        style={[
          styles.container,
          elevation.artworkShadow,
          {
            backgroundColor: colors.surface2,
            borderColor: colors.separator,
          },
        ]}
      >
        <Ionicons name={iconName} size={layoutTokens.iconSizeMd} color={iconColor} />
        <Text style={[typography.subhead, styles.text, { color: colors.text }]} numberOfLines={2}>
          {current.message}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    position: 'absolute',
    left: spacing.md,
    right: spacing.md,
    alignItems: 'center',
    zIndex: zIndices.toast,
  },
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    maxWidth: layoutTokens.toastMaxWidth,
    width: '100%',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radii.sheet,
    borderWidth: layoutTokens.hairline,
  },
  text: {
    flex: 1,
  },
});
