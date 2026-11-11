import { BlurView } from 'expo-blur';
import { Tabs } from 'expo-router';
import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { DesktopSidebar } from '@/components/DesktopSidebar';
import { MiniPlayer } from '@/components/MiniPlayer';
import { NowPlaying } from '@/components/NowPlaying';
import { PlayerBar } from '@/components/PlayerBar';
import { QueueModal } from '@/components/QueuePanel';
import { useKeyboardShortcuts } from '@/hooks/useKeyboardShortcuts';
import { useLayout } from '@/hooks/useLayout';
import { usePlayerStore } from '@/store/player';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens } from '@/theme/tokens';

export default function TabsLayout() {
  const { colors } = useTheme();
  const { isDesktop } = useLayout();
  const restorePlayer = usePlayerStore((s) => s.restore);

  useEffect(() => {
    void restorePlayer();
  }, [restorePlayer]);

  useKeyboardShortcuts(true);

  return (
    <View style={[styles.shell, { backgroundColor: colors.background }]}>
      <View style={styles.mainRow}>
        {isDesktop ? <DesktopSidebar /> : null}
        <View style={styles.content}>
          <Tabs
            screenOptions={{
              headerShown: false,
              tabBarActiveTintColor: colors.accent,
              tabBarInactiveTintColor: colors.textSecondary,
              tabBarStyle: isDesktop
                ? { display: 'none' }
                : {
                    position: 'absolute',
                    backgroundColor: 'transparent',
                    borderTopWidth: layoutTokens.hairline,
                    borderTopColor: colors.separator,
                    elevation: 0,
                  },
              tabBarBackground: () =>
                isDesktop ? null : (
                  <BlurView
                    intensity={80}
                    tint={colors.blurTint}
                    style={StyleSheet.absoluteFill}
                  />
                ),
            }}
          >
            <Tabs.Screen
              name="index"
              options={{
                title: 'Listen Now',
                tabBarIcon: ({ color, size }) => (
                  <Ionicons
                    name="play-circle"
                    size={size}
                    color={typeof color === 'string' ? color : colors.textSecondary}
                  />
                ),
              }}
            />
            <Tabs.Screen
              name="browse"
              options={{
                title: 'Browse',
                tabBarIcon: ({ color, size }) => (
                  <Ionicons
                    name="grid"
                    size={size}
                    color={typeof color === 'string' ? color : colors.textSecondary}
                  />
                ),
              }}
            />
            <Tabs.Screen
              name="library"
              options={{
                title: 'Library',
                tabBarIcon: ({ color, size }) => (
                  <Ionicons
                    name="library"
                    size={size}
                    color={typeof color === 'string' ? color : colors.textSecondary}
                  />
                ),
              }}
            />
            <Tabs.Screen
              name="search"
              options={{
                title: 'Search',
                tabBarIcon: ({ color, size }) => (
                  <Ionicons
                    name="search"
                    size={size}
                    color={typeof color === 'string' ? color : colors.textSecondary}
                  />
                ),
              }}
            />
          </Tabs>

          {!isDesktop ? <MiniPlayer /> : null}
        </View>
      </View>

      {isDesktop ? <PlayerBar /> : null}
      <NowPlaying />
      <QueueModal />
    </View>
  );
}

const styles = StyleSheet.create({
  shell: {
    flex: 1,
  },
  mainRow: {
    flex: 1,
    flexDirection: 'row',
  },
  content: {
    flex: 1,
  },
});
