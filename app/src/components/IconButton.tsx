import React from 'react';
import { Pressable, StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing } from '@/theme/tokens';

export type IoniconName = React.ComponentProps<typeof Ionicons>['name'];

export interface IconButtonProps {
  name: IoniconName;
  size?: number;
  color?: string;
  onPress: () => void;
  accessibilityLabel: string;
  testID?: string;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function IconButton({
  name,
  size = layoutTokens.iconSizeMd,
  color,
  onPress,
  accessibilityLabel,
  testID,
  disabled = false,
  style,
}: IconButtonProps) {
  const { colors } = useTheme();
  const iconColor = disabled ? colors.textTertiary : (color ?? colors.text);

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      hitSlop={layoutTokens.hitSlop}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ disabled }}
      testID={testID}
      style={({ pressed }) => [
        styles.base,
        pressed && !disabled ? styles.pressed : undefined,
        style,
      ]}
    >
      <Ionicons name={name} size={size} color={iconColor} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xs,
    borderRadius: radii.pill,
  },
  pressed: {
    opacity: 0.65,
  },
});

