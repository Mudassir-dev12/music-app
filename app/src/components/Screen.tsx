import React, { useState } from 'react';
import {
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useLayout } from '@/hooks/useLayout';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, spacing, typography } from '@/theme/tokens';

export interface ScreenProps {
  title: string;
  headerRight?: React.ReactNode;
  children: React.ReactNode;
  bottomInset?: number;
  scrollEnabled?: boolean;
  testID?: string;
}

export function Screen({
  title,
  headerRight,
  children,
  bottomInset = spacing.xxl,
  scrollEnabled = true,
  testID,
}: ScreenProps) {
  const { colors } = useTheme();
  const { pagePadding } = useLayout();
  const [collapsed, setCollapsed] = useState(false);

  const handleScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const y = e.nativeEvent.contentOffset.y;
    const next = y > spacing.xxl;
    if (next !== collapsed) {
      setCollapsed(next);
    }
  };

  return (
    <SafeAreaView
      edges={['top', 'left', 'right']}
      style={[styles.root, { backgroundColor: colors.background }]}
      testID={testID}
    >
      <View
        style={[
          styles.stickyBar,
          {
            paddingHorizontal: pagePadding,
            borderBottomColor: collapsed ? colors.separator : 'transparent',
            borderBottomWidth: collapsed ? layoutTokens.hairline : 0,
          },
        ]}
      >
        <View style={styles.stickySpacer} />
        <Text
          style={[
            typography.headline,
            styles.stickyTitle,
            { color: colors.text, opacity: collapsed ? 1 : 0 },
          ]}
          numberOfLines={1}
        >
          {title}
        </Text>
        <View style={styles.stickyRight}>{headerRight}</View>
      </View>

      <ScrollView
        scrollEnabled={scrollEnabled}
        onScroll={handleScroll}
        scrollEventThrottle={16}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={[
          styles.content,
          { paddingHorizontal: pagePadding, paddingBottom: bottomInset },
        ]}
      >
        <Text
          style={[typography.largeTitle, styles.largeTitle, { color: colors.text }]}
          accessibilityRole="header"
        >
          {title}
        </Text>
        {children}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  stickyBar: {
    height: layoutTokens.artMini,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  stickySpacer: {
    width: layoutTokens.artMini,
  },
  stickyTitle: {
    flex: 1,
    textAlign: 'center',
  },
  stickyRight: {
    minWidth: layoutTokens.artMini,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  content: {
    gap: spacing.lg,
  },
  largeTitle: {
    marginBottom: spacing.xs,
  },
});
