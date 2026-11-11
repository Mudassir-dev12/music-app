import React from 'react';
import { Pressable, StyleSheet, Text, type StyleProp, type ViewStyle } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { type IoniconName } from '@/components/IconButton';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';

export interface PillButtonProps {
  label: string;
  icon?: IoniconName;
  variant?: 'accent' | 'surface';
  onPress: () => void;
  disabled?: boolean;
  accessibilityLabel?: string;
  testID?: string;
  style?: StyleProp<ViewStyle>;
}

export function PillButton({
  label,
  icon,
  variant = 'surface',
  onPress,
  disabled = false,
  accessibilityLabel,
  testID,
  style,
}: PillButtonProps) {
  const { colors } = useTheme();
  const bg = variant === 'accent' ? colors.accent : colors.surface2;
  const fg = variant === 'accent' ? colors.onAccent : colors.accent;

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ disabled }}
      testID={testID}
      style={({ pressed }) => [
        styles.button,
        { backgroundColor: bg, opacity: disabled ? 0.45 : pressed ? 0.78 : 1 },
        style,
      ]}
    >
      {icon ? <Ionicons name={icon} size={layoutTokens.iconSizeSm} color={fg} /> : null}
      <Text style={[typography.headline, { color: fg }]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
  },
});
