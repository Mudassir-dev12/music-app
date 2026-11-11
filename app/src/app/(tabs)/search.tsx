import AsyncStorage from '@react-native-async-storage/async-storage';
import { useQuery } from '@tanstack/react-query';
import { useLocalSearchParams } from 'expo-router';
import React, { useCallback, useEffect, useState } from 'react';
import {
  Keyboard,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { api, ApiError } from '@/api/client';
import type { Track } from '@/api/types';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { IconButton } from '@/components/IconButton';
import { Screen } from '@/components/Screen';
import { SectionHeader } from '@/components/SectionHeader';
import { TrackRowSkeleton } from '@/components/Skeleton';
import { TrackRow } from '@/components/TrackRow';
import { useDebounce } from '@/hooks/useDebounce';
import { useLayout } from '@/hooks/useLayout';
import { getCurrentTrack } from '@/player/queue';
import { usePlayerStore } from '@/store/player';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';

const RECENT_SEARCHES_KEY = 'melodia.recent_searches';
const MAX_RECENT_SEARCHES = 8;

export default function SearchScreen() {
  const { colors } = useTheme();
  const { isPhone } = useLayout();
  const params = useLocalSearchParams<{ q?: string }>();
  const [query, setQuery] = useState('');
  const [focused, setFocused] = useState(false);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const [actionTrack, setActionTrack] = useState<Track | null>(null);

  const playerStore = usePlayerStore();
  const currentTrack = getCurrentTrack(playerStore);
  const paramQ = typeof params.q === 'string' ? params.q.trim() : '';
  const [lastParamQ, setLastParamQ] = useState(paramQ);

  if (paramQ && paramQ !== lastParamQ) {
    setLastParamQ(paramQ);
    setQuery(paramQ);
  }

  useEffect(() => {
    AsyncStorage.getItem(RECENT_SEARCHES_KEY)
      .then((raw) => {
        if (!raw) return;
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          setRecentSearches(parsed.filter((s): s is string => typeof s === 'string'));
        }
      })
      .catch(() => {});
  }, []);

  const saveRecentSearch = useCallback((term: string) => {
    const clean = term.trim();
    if (!clean) return;
    setRecentSearches((prev) => {
      const next = [clean, ...prev.filter((item) => item.toLowerCase() !== clean.toLowerCase())].slice(
        0,
        MAX_RECENT_SEARCHES
      );
      AsyncStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(next)).catch(() => {});
      return next;
    });
  }, []);

  const clearRecentSearches = useCallback(() => {
    setRecentSearches([]);
    AsyncStorage.removeItem(RECENT_SEARCHES_KEY).catch(() => {});
  }, []);

  const trimmedQuery = query.trim();
  const debouncedQuery = useDebounce(trimmedQuery, 300);

  const searchQuery = useQuery({
    queryKey: ['search', 'songs', debouncedQuery],
    queryFn: async () => {
      const res = await api.searchSongs(debouncedQuery, 25);
      saveRecentSearch(debouncedQuery);
      return res;
    },
    enabled: debouncedQuery.length > 0,
  });

  const results = searchQuery.data?.results ?? [];

  const handleCancel = () => {
    setQuery('');
    setFocused(false);
    Keyboard.dismiss();
  };

  const errorMessage =
    searchQuery.error instanceof ApiError
      ? searchQuery.error.status === 429
        ? `Rate limit reached. Try again in ${searchQuery.error.retryAfterSec ?? 60}s.`
        : searchQuery.error.detail
      : searchQuery.error instanceof Error
        ? searchQuery.error.message
        : 'Unable to search right now.';

  return (
    <Screen title="Search" testID="screen-search">
      <View style={styles.searchRow}>
        <View
          style={[
            styles.inputWrap,
            { backgroundColor: colors.surface, borderColor: colors.separator },
          ]}
        >
          <Ionicons name="search" size={layoutTokens.iconSizeMd} color={colors.textSecondary} />
          <TextInput
            value={query}
            onChangeText={setQuery}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            placeholder="Songs, artists..."
            placeholderTextColor={colors.textTertiary}
            returnKeyType="search"
            autoCorrect={false}
            testID="search-input"
            accessibilityLabel="Search songs"
            style={[typography.body, styles.input, { color: colors.text }]}
          />
          {query.length > 0 ? (
            <IconButton
              name="close-circle"
              size={layoutTokens.iconSizeSm + spacing.xxs}
              color={colors.textSecondary}
              onPress={() => setQuery('')}
              accessibilityLabel="Clear search"
              testID="search-clear"
            />
          ) : null}
        </View>

        {isPhone && (focused || query.length > 0) ? (
          <Pressable
            onPress={handleCancel}
            accessibilityRole="button"
            testID="search-cancel"
            style={styles.cancelBtn}
          >
            <Text style={[typography.callout, { color: colors.accent }]}>Cancel</Text>
          </Pressable>
        ) : null}
      </View>

      {trimmedQuery.length === 0 ? (
        recentSearches.length > 0 ? (
          <View style={styles.recentSection} testID="recent-searches">
            <SectionHeader
              title="Recent Searches"
              seeAllLabel="Clear"
              onSeeAll={clearRecentSearches}
            />
            {recentSearches.map((term, idx) => (
              <Pressable
                key={`${term}-${idx}`}
                onPress={() => setQuery(term)}
                accessibilityRole="button"
                testID={`recent-search-${idx}`}
                style={({ pressed }) => [
                  styles.recentRow,
                  {
                    borderBottomColor: colors.separator,
                    backgroundColor: pressed ? colors.surface : 'transparent',
                  },
                ]}
              >
                <Ionicons
                  name="time-outline"
                  size={layoutTokens.iconSizeMd}
                  color={colors.textSecondary}
                />
                <Text style={[typography.body, { color: colors.text }]}>{term}</Text>
              </Pressable>
            ))}
          </View>
        ) : (
          <EmptyState
            icon="search-outline"
            title="Search for Songs"
            message="Find tracks by song title or artist."
            testID="search-empty"
          />
        )
      ) : searchQuery.isLoading || (trimmedQuery !== debouncedQuery && results.length === 0) ? (
        <View style={styles.skeletons} testID="search-loading">
          {Array.from({ length: 6 }).map((_, idx) => (
            <TrackRowSkeleton key={idx} />
          ))}
        </View>
      ) : searchQuery.isError ? (
        <ErrorState
          message={errorMessage}
          onRetry={() => {
            void searchQuery.refetch();
          }}
          testID="search-error"
        />
      ) : results.length === 0 ? (
        <EmptyState
          icon="musical-notes-outline"
          title="No Songs Found"
          message={`No results matched "${debouncedQuery}".`}
          testID="search-no-results"
        />
      ) : (
        <View testID="search-results">
          {results.map((track, idx) => {
            const isCurrent = currentTrack?.video_id === track.video_id;
            return (
              <TrackRow
                key={`${track.video_id}-${idx}`}
                track={track}
                isCurrent={isCurrent}
                isPlaying={isCurrent && playerStore.isPlaying}
                showSeparator={idx < results.length - 1}
                onPress={() => {
                  saveRecentSearch(debouncedQuery);
                  void playerStore.playTracks(results, idx, `Search: ${debouncedQuery}`);
                }}
                onMorePress={() => setActionTrack(track)}
                testID={`search-result-${idx}`}
              />
            );
          })}
        </View>
      )}

      <Modal
        visible={Boolean(actionTrack)}
        transparent
        animationType="fade"
        onRequestClose={() => setActionTrack(null)}
      >
        <Pressable
          style={[styles.modalBackdrop, { backgroundColor: colors.overlayMedium }]}
          onPress={() => setActionTrack(null)}
        >
          <Pressable
            onPress={(e) => e.stopPropagation()}
            style={[
              styles.actionSheet,
              { backgroundColor: colors.surface, borderColor: colors.separator },
            ]}
            testID="track-context-menu"
          >
            {actionTrack ? (
              <>
                <View style={[styles.sheetHeader, { borderBottomColor: colors.separator }]}>
                  <Text style={[typography.headline, { color: colors.text }]} numberOfLines={1}>
                    {actionTrack.title}
                  </Text>
                  <Text style={[typography.footnote, { color: colors.textSecondary }]} numberOfLines={1}>
                    {actionTrack.artist}
                  </Text>
                </View>

                <Pressable
                  onPress={() => {
                    const t = actionTrack;
                    setActionTrack(null);
                    void playerStore.enqueueNext(t);
                  }}
                  style={styles.sheetAction}
                  testID="context-play-next"
                >
                  <Ionicons
                    name="play-skip-forward-outline"
                    size={layoutTokens.iconSizeMd}
                    color={colors.text}
                  />
                  <Text style={[typography.body, { color: colors.text }]}>Play Next</Text>
                </Pressable>

                <Pressable
                  onPress={() => {
                    const t = actionTrack;
                    setActionTrack(null);
                    void playerStore.enqueueLast(t);
                  }}
                  style={styles.sheetAction}
                  testID="context-add-to-queue"
                >
                  <Ionicons name="list-outline" size={layoutTokens.iconSizeMd} color={colors.text} />
                  <Text style={[typography.body, { color: colors.text }]}>Add to Queue</Text>
                </Pressable>
              </>
            ) : null}
          </Pressable>
        </Pressable>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  inputWrap: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    borderRadius: radii.card,
    borderWidth: layoutTokens.hairline,
    paddingLeft: spacing.sm,
    paddingRight: spacing.xs,
    height: spacing.xxxl + spacing.xxs,
  },
  input: {
    flex: 1,
    paddingVertical: spacing.xs,
  },
  cancelBtn: {
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
  },
  recentSection: {
    gap: spacing.xs,
  },
  recentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    borderBottomWidth: layoutTokens.hairline,
  },
  skeletons: {
    gap: spacing.xs,
  },
  modalBackdrop: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.lg,
  },
  actionSheet: {
    width: '100%',
    maxWidth: layoutTokens.maxFormWidth,
    borderRadius: radii.sheet,
    borderWidth: layoutTokens.hairline,
    overflow: 'hidden',
  },
  sheetHeader: {
    padding: spacing.md,
    borderBottomWidth: layoutTokens.hairline,
    gap: spacing.xxs / 2,
  },
  sheetAction: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.md,
  },
});
