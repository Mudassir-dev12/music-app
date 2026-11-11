import { usePathname, useRouter } from 'expo-router';
import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { IconButton, type IoniconName } from '@/components/IconButton';
import { config } from '@/lib/config';
import { useSessionStore } from '@/store/session';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';
import { getInitials } from '@/utils/format';

interface NavItem {
  label: string;
  href: '/' | '/browse' | '/library' | '/search';
  matchPath: string;
  icon: IoniconName;
}

const NAV_ITEMS: NavItem[] = [
  { label: 'Listen Now', href: '/', matchPath: '/', icon: 'play-circle' },
  { label: 'Browse', href: '/browse', matchPath: '/browse', icon: 'grid' },
  { label: 'Library', href: '/library', matchPath: '/library', icon: 'library' },
];

export function DesktopSidebar() {
  const { colors } = useTheme();
  const { user, signOut } = useSessionStore();
  const router = useRouter();
  const pathname = usePathname();
  const [quickQuery, setQuickQuery] = useState('');

  const submitSearch = () => {
    const trimmed = quickQuery.trim();
    router.push(trimmed ? { pathname: '/search', params: { q: trimmed } } : '/search');
  };

  const initials = getInitials(user?.display_name, user?.email);

  return (
    <View
      style={[
        styles.sidebar,
        {
          backgroundColor: colors.surface,
          borderRightColor: colors.separator,
        },
      ]}
      testID="desktop-sidebar"
    >
      <View style={styles.topSection}>
        <Text style={[typography.title2, styles.brand, { color: colors.text }]}>
          {config.appName}
        </Text>

        <View
          style={[
            styles.searchBox,
            { backgroundColor: colors.surface2, borderColor: colors.separator },
          ]}
        >
          <Ionicons name="search" size={layoutTokens.iconSizeSm} color={colors.textSecondary} />
          <TextInput
            value={quickQuery}
            onChangeText={setQuickQuery}
            onFocus={() => {
              if (pathname !== '/search') {
                router.push('/search');
              }
            }}
            onSubmitEditing={submitSearch}
            placeholder="Search"
            placeholderTextColor={colors.textTertiary}
            returnKeyType="search"
            testID="sidebar-search-input"
            accessibilityLabel="Search songs"
            style={[typography.subhead, styles.searchInput, { color: colors.text }]}
          />
          {quickQuery ? (
            <IconButton
              name="close-circle"
              size={layoutTokens.iconSizeSm}
              color={colors.textSecondary}
              onPress={() => setQuickQuery('')}
              accessibilityLabel="Clear sidebar search"
            />
          ) : null}
        </View>

        <View style={styles.navList}>
          {NAV_ITEMS.map((item) => {
            const active =
              item.matchPath === '/'
                ? pathname === '/' || pathname === '/index'
                : pathname.startsWith(item.matchPath);
            return (
              <Pressable
                key={item.href}
                onPress={() => router.push(item.href)}
                accessibilityRole="button"
                accessibilityState={{ selected: active }}
                testID={`sidebar-nav-${item.label.toLowerCase().replace(/\s+/g, '-')}`}
                style={({ pressed }) => [
                  styles.navItem,
                  {
                    backgroundColor: active
                      ? colors.surface2
                      : pressed
                        ? colors.overlayLight
                        : 'transparent',
                  },
                ]}
              >
                <Ionicons
                  name={item.icon}
                  size={layoutTokens.iconSizeMd}
                  color={active ? colors.accent : colors.textSecondary}
                />
                <Text
                  style={[
                    typography.callout,
                    styles.navLabel,
                    { color: active ? colors.text : colors.textSecondary },
                  ]}
                >
                  {item.label}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.playlistsSection}>
          <Text style={[typography.footnote, styles.sectionTitle, { color: colors.textTertiary }]}>
            PLAYLISTS
          </Text>
          <Text style={[typography.footnote, { color: colors.textSecondary }]}>
            Playlists arrive in Phase 3
          </Text>
        </View>
      </View>

      <View style={[styles.userRow, { borderTopColor: colors.separator }]}>
        <View style={[styles.avatar, { backgroundColor: colors.accent }]}>
          <Text style={[typography.caption, styles.avatarText, { color: colors.onAccent }]}>
            {initials}
          </Text>
        </View>
        <View style={styles.userMeta}>
          <Text style={[typography.subhead, styles.userName, { color: colors.text }]} numberOfLines={1}>
            {user?.display_name || user?.email || 'Account'}
          </Text>
          {user?.display_name ? (
            <Text style={[typography.caption, { color: colors.textSecondary }]} numberOfLines={1}>
              {user.email}
            </Text>
          ) : null}
        </View>
        <IconButton
          name="log-out-outline"
          color={colors.textSecondary}
          onPress={() => {
            void signOut();
          }}
          accessibilityLabel="Sign out"
          testID="sidebar-signout"
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  sidebar: {
    width: layoutTokens.sidebarWidth,
    borderRightWidth: layoutTokens.hairline,
    padding: spacing.md,
    justifyContent: 'space-between',
  },
  topSection: {
    gap: spacing.lg,
  },
  brand: {
    paddingHorizontal: spacing.xs,
    paddingTop: spacing.xs,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    borderRadius: radii.card,
    borderWidth: layoutTokens.hairline,
    paddingHorizontal: spacing.sm,
    height: spacing.xxl + spacing.xxs,
  },
  searchInput: {
    flex: 1,
    paddingVertical: spacing.xxs,
  },
  navList: {
    gap: spacing.xxs,
  },
  navItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs + spacing.xxs / 2,
    borderRadius: radii.card,
  },
  navLabel: {
    fontWeight: '600',
  },
  playlistsSection: {
    gap: spacing.xs,
    paddingHorizontal: spacing.xs,
    paddingTop: spacing.sm,
  },
  sectionTitle: {
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  userRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingTop: spacing.md,
    borderTopWidth: layoutTokens.hairline,
  },
  avatar: {
    width: layoutTokens.avatarSize,
    height: layoutTokens.avatarSize,
    borderRadius: radii.pill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontWeight: '700',
  },
  userMeta: {
    flex: 1,
  },
  userName: {
    fontWeight: '600',
  },
});
