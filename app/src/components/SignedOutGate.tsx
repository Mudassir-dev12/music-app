import { Redirect, useSegments } from 'expo-router';
import React, { useEffect } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { config } from '@/lib/config';
import { useSessionStore } from '@/store/session';
import { useTheme } from '@/theme/ThemeProvider';
import { spacing, typography } from '@/theme/tokens';

export function SignedOutGate({ children }: { children: React.ReactNode }) {
  const { user, hydrated, bootstrap } = useSessionStore();
  const segments = useSegments();
  const { colors } = useTheme();

  useEffect(() => {
    void bootstrap();
  }, [bootstrap]);

  const inAuthGroup = segments[0] === 'auth';

  if (!hydrated) {
    return (
      <View
        style={[styles.splash, { backgroundColor: colors.background }]}
        testID="session-splash"
      >
        <Text style={[typography.title1, { color: colors.text }]}>{config.appName}</Text>
        <ActivityIndicator size="small" color={colors.accent} />
      </View>
    );
  }

  if (!user && !inAuthGroup) {
    return <Redirect href="/auth/sign-in" />;
  }

  if (user && inAuthGroup) {
    return <Redirect href="/" />;
  }

  return <>{children}</>;
}

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
  },
});
