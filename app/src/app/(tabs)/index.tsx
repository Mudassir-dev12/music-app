import React, { useState } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { AlbumCard } from '@/components/AlbumCard';
import { Carousel } from '@/components/Carousel';
import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';
import { SectionHeader } from '@/components/SectionHeader';
import { usePlayerStore } from '@/store/player';
import { useSessionStore } from '@/store/session';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, type ThemeMode, typography } from '@/theme/tokens';
import { getInitials } from '@/utils/format';

const THEME_OPTIONS: { label: string; value: ThemeMode }[] = [
  { label: 'System', value: 'system' },
  { label: 'Light', value: 'light' },
  { label: 'Dark', value: 'dark' },
];

export default function ListenNowScreen() {
  const { colors, mode, setMode } = useTheme();
  const { user, signOut } = useSessionStore();
  const { recentlyPlayed, playTracks } = usePlayerStore();
  const [menuOpen, setMenuOpen] = useState(false);

  const initials = getInitials(user?.display_name, user?.email);

  const avatarButton = (
    <Pressable
      onPress={() => setMenuOpen(true)}
      accessibilityRole="button"
      accessibilityLabel="Account and theme menu"
      testID="listen-now-avatar"
      style={[styles.avatar, { backgroundColor: colors.accent }]}
    >
      <Text style={[typography.caption, styles.avatarText, { color: colors.onAccent }]}>
        {initials}
      </Text>
    </Pressable>
  );

  return (
    <Screen title="Listen Now" headerRight={avatarButton} testID="screen-listen-now">
      {recentlyPlayed.length > 0 ? (
        <View style={styles.section}>
          <SectionHeader title="Recently Played" />
          <Carousel
            data={recentlyPlayed}
            keyExtractor={(item, idx) => `${item.video_id}-${idx}`}
            testID="recently-played-carousel"
            renderItem={({ item, index }) => (
              <AlbumCard
                title={item.title}
                subtitle={item.artist}
                artworkUrl={item.thumbnail}
                onPress={() => {
                  void playTracks(recentlyPlayed, index, 'Recently Played');
                }}
                testID={`recent-card-${index}`}
              />
            )}
          />
        </View>
      ) : (
        <EmptyState
          icon="play-circle-outline"
          title="Nothing Played Yet"
          message="Songs you play from Search will appear here under Recently Played."
          testID="listen-now-empty"
        />
      )}

      <Modal
        visible={menuOpen}
        transparent
        animationType="fade"
        onRequestClose={() => setMenuOpen(false)}
      >
        <Pressable
          style={[styles.backdrop, { backgroundColor: colors.overlayMedium }]}
          onPress={() => setMenuOpen(false)}
        >
          <Pressable
            onPress={(e) => e.stopPropagation()}
            style={[
              styles.menuCard,
              { backgroundColor: colors.surface, borderColor: colors.separator },
            ]}
            testID="account-menu"
          >
            <View style={[styles.menuHeader, { borderBottomColor: colors.separator }]}>
              <Text style={[typography.headline, { color: colors.text }]} numberOfLines={1}>
                {user?.display_name || user?.email || 'Account'}
              </Text>
              {user?.display_name ? (
                <Text style={[typography.caption, { color: colors.textSecondary }]} numberOfLines={1}>
                  {user.email}
                </Text>
              ) : null}
            </View>

            <View style={styles.themeBlock}>
              <Text style={[typography.footnote, { color: colors.textSecondary }]}>Theme</Text>
              <View style={styles.themeRow}>
                {THEME_OPTIONS.map((opt) => {
                  const selected = mode === opt.value;
                  return (
                    <Pressable
                      key={opt.value}
                      onPress={() => setMode(opt.value)}
                      accessibilityRole="button"
                      accessibilityState={{ selected }}
                      testID={`theme-option-${opt.value}`}
                      style={[
                        styles.themePill,
                        {
                          backgroundColor: selected ? colors.accent : colors.surface2,
                        },
                      ]}
                    >
                      <Text
                        style={[
                          typography.footnote,
                          styles.themePillText,
                          { color: selected ? colors.onAccent : colors.text },
                        ]}
                      >
                        {opt.label}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </View>

            <Pressable
              onPress={() => {
                setMenuOpen(false);
                void signOut();
              }}
              accessibilityRole="button"
              testID="menu-signout"
              style={[styles.signOutRow, { borderTopColor: colors.separator }]}
            >
              <Ionicons
                name="log-out-outline"
                size={layoutTokens.iconSizeMd}
                color={colors.destructive}
              />
              <Text style={[typography.body, { color: colors.destructive }]}>Sign Out</Text>
            </Pressable>
          </Pressable>
        </Pressable>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  section: {
    gap: spacing.sm,
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
  backdrop: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.lg,
  },
  menuCard: {
    width: '100%',
    maxWidth: layoutTokens.maxFormWidth,
    borderRadius: radii.sheet,
    borderWidth: layoutTokens.hairline,
    overflow: 'hidden',
  },
  menuHeader: {
    padding: spacing.md,
    borderBottomWidth: layoutTokens.hairline,
    gap: spacing.xxs / 2,
  },
  themeBlock: {
    padding: spacing.md,
    gap: spacing.sm,
  },
  themeRow: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  themePill: {
    flex: 1,
    paddingVertical: spacing.xs,
    borderRadius: radii.pill,
    alignItems: 'center',
  },
  themePillText: {
    fontWeight: '600',
  },
  signOutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderTopWidth: layoutTokens.hairline,
  },
});
