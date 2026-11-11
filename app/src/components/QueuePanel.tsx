import React, { useMemo } from 'react';
import {
  Modal,
  PanResponder,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';

import type { Track } from '@/api/types';
import { EmptyState } from '@/components/EmptyState';
import { EqualizerBars } from '@/components/EqualizerBars';
import { IconButton } from '@/components/IconButton';
import { getCurrentTrack, getUpNext } from '@/player/queue';
import { usePlayerStore } from '@/store/player';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';

function QueueItemRow({
  track,
  onPress,
  onRemove,
  onMoveUp,
  onMoveDown,
  canMoveUp,
  canMoveDown,
  testID,
}: {
  track: Track;
  onPress: () => void;
  onRemove: () => void;
  onMoveUp?: () => void;
  onMoveDown?: () => void;
  canMoveUp?: boolean;
  canMoveDown?: boolean;
  testID: string;
}) {
  const { colors } = useTheme();

  const swipeResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 18 && Math.abs(g.dy) < 12,
        onPanResponderRelease: (_, g) => {
          if (g.dx < -56) {
            onRemove();
          }
        },
      }),
    [onRemove]
  );

  return (
    <View
      {...swipeResponder.panHandlers}
      style={[styles.itemRow, { borderBottomColor: colors.separator }]}
      testID={testID}
    >
      <Pressable onPress={onPress} style={styles.itemMain} accessibilityRole="button">
        <View style={[styles.thumbWrap, { backgroundColor: colors.surface2 }]}>
          {track.thumbnail ? (
            <Image source={{ uri: track.thumbnail }} style={styles.thumb} contentFit="cover" />
          ) : (
            <Ionicons name="musical-note" size={layoutTokens.iconSizeSm} color={colors.textTertiary} />
          )}
        </View>
        <View style={styles.itemText}>
          <Text style={[typography.subhead, styles.itemTitle, { color: colors.text }]} numberOfLines={1}>
            {track.title}
          </Text>
          <Text style={[typography.caption, { color: colors.textSecondary }]} numberOfLines={1}>
            {track.artist}
          </Text>
        </View>
      </Pressable>

      <View style={styles.itemActions}>
        {onMoveUp ? (
          <IconButton
            name="chevron-up"
            size={layoutTokens.iconSizeSm}
            color={colors.textSecondary}
            disabled={!canMoveUp}
            onPress={onMoveUp}
            accessibilityLabel={`Move ${track.title} up`}
            testID={`${testID}-up`}
          />
        ) : null}
        {onMoveDown ? (
          <IconButton
            name="chevron-down"
            size={layoutTokens.iconSizeSm}
            color={colors.textSecondary}
            disabled={!canMoveDown}
            onPress={onMoveDown}
            accessibilityLabel={`Move ${track.title} down`}
            testID={`${testID}-down`}
          />
        ) : null}
        <Ionicons
          name="reorder-three"
          size={layoutTokens.iconSizeMd}
          color={colors.textTertiary}
        />
        <IconButton
          name="close-circle-outline"
          size={layoutTokens.iconSizeSm + spacing.xxs}
          color={colors.textSecondary}
          onPress={onRemove}
          accessibilityLabel={`Remove ${track.title} from queue`}
          testID={`${testID}-remove`}
        />
      </View>
    </View>
  );
}

export function QueueContent({
  embedded = false,
  onClose,
}: {
  embedded?: boolean;
  onClose?: () => void;
}) {
  const { colors } = useTheme();
  const store = usePlayerStore();
  const currentTrack = getCurrentTrack(store);
  const upNext = getUpNext(store);

  const repeatIcon = store.repeat === 'off' ? 'repeat-outline' : 'repeat';

  return (
    <View
      style={[
        styles.panel,
        { backgroundColor: embedded ? 'transparent' : colors.surface },
      ]}
      testID="queue-panel"
    >
      <View style={[styles.header, { borderBottomColor: colors.separator }]}>
        <Text style={[typography.title3, { color: colors.text }]}>Queue</Text>
        <View style={styles.headerControls}>
          <Pressable
            onPress={store.toggleShuffle}
            accessibilityRole="button"
            accessibilityLabel="Toggle shuffle"
            accessibilityState={{ selected: store.shuffle }}
            testID="queue-shuffle"
            style={[
              styles.togglePill,
              {
                backgroundColor: store.shuffle ? colors.accent : colors.surface2,
              },
            ]}
          >
            <Ionicons
              name="shuffle"
              size={layoutTokens.iconSizeSm}
              color={store.shuffle ? colors.onAccent : colors.text}
            />
          </Pressable>

          <Pressable
            onPress={store.cycleRepeat}
            accessibilityRole="button"
            accessibilityLabel={`Repeat mode: ${store.repeat}`}
            testID="queue-repeat"
            style={[
              styles.togglePill,
              {
                backgroundColor: store.repeat !== 'off' ? colors.accent : colors.surface2,
              },
            ]}
          >
            <Ionicons
              name={repeatIcon}
              size={layoutTokens.iconSizeSm}
              color={store.repeat !== 'off' ? colors.onAccent : colors.text}
            />
            {store.repeat === 'one' ? (
              <Text style={[typography.caption, styles.oneBadge, { color: colors.onAccent }]}>
                1
              </Text>
            ) : null}
          </Pressable>

          {!embedded && onClose ? (
            <IconButton
              name="close"
              onPress={onClose}
              accessibilityLabel="Close queue"
              testID="queue-close"
            />
          ) : null}
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={[typography.footnote, styles.sectionLabel, { color: colors.textSecondary }]}>
          NOW PLAYING
        </Text>
        {currentTrack ? (
          <View
            style={[styles.nowPlayingRow, { backgroundColor: colors.surface2 }]}
            testID="queue-now-playing-row"
          >
            <View style={[styles.thumbWrap, { backgroundColor: colors.surface }]}>
              {currentTrack.thumbnail ? (
                <Image
                  source={{ uri: currentTrack.thumbnail }}
                  style={styles.thumb}
                  contentFit="cover"
                />
              ) : (
                <Ionicons
                  name="musical-note"
                  size={layoutTokens.iconSizeSm}
                  color={colors.textTertiary}
                />
              )}
            </View>
            <View style={styles.itemText}>
              <Text style={[typography.headline, { color: colors.accent }]} numberOfLines={1}>
                {currentTrack.title}
              </Text>
              <Text style={[typography.caption, { color: colors.textSecondary }]} numberOfLines={1}>
                {currentTrack.artist}
              </Text>
            </View>
            <EqualizerBars playing={store.isPlaying} />
          </View>
        ) : (
          <EmptyState
            icon="musical-notes-outline"
            title="Queue is Empty"
            message="Search for a song to start playing."
          />
        )}

        <View style={styles.sectionHeaderRow}>
          <Text style={[typography.footnote, styles.sectionLabel, { color: colors.textSecondary }]}>
            PLAYING NEXT
          </Text>
          {store.playNext.length > 0 ? (
            <Pressable
              onPress={store.clearPlayNext}
              accessibilityRole="button"
              testID="queue-clear-playnext"
            >
              <Text style={[typography.footnote, { color: colors.accent }]}>Clear</Text>
            </Pressable>
          ) : null}
        </View>
        {store.playNext.length === 0 ? (
          <Text style={[typography.footnote, styles.emptySub, { color: colors.textTertiary }]}>
            No tracks added to Playing Next.
          </Text>
        ) : (
          store.playNext.map((track, idx) => (
            <QueueItemRow
              key={`pn-${track.video_id}-${idx}`}
              track={track}
              testID={`queue-playnext-${idx}`}
              onPress={() => {
                // Jump directly to this queued item by trimming prior playNext items
                const rest = store.playNext.slice(idx);
                usePlayerStore.setState({ playNext: rest });
                void store.nextTrack(false);
              }}
              onMoveUp={() => store.movePlayNextItem(idx, idx - 1)}
              onMoveDown={() => store.movePlayNextItem(idx, idx + 1)}
              canMoveUp={idx > 0}
              canMoveDown={idx < store.playNext.length - 1}
              onRemove={() => store.removePlayNextItem(idx)}
            />
          ))
        )}

        <Text style={[typography.footnote, styles.sectionLabel, { color: colors.textSecondary }]}>
          UP NEXT{store.sourceLabel ? ` · ${store.sourceLabel.toUpperCase()}` : ''}
        </Text>
        {upNext.length === 0 ? (
          <Text style={[typography.footnote, styles.emptySub, { color: colors.textTertiary }]}>
            End of queue.
          </Text>
        ) : (
          upNext.map((track, idx) => {
            const absIdx = store.currentIndex + 1 + idx;
            return (
              <QueueItemRow
                key={`un-${track.video_id}-${absIdx}`}
                track={track}
                testID={`queue-upnext-${idx}`}
                onPress={() => {
                  void store.playTracks(store.queue, absIdx, store.sourceLabel);
                }}
                onMoveUp={() => store.moveQueueItem(absIdx, absIdx - 1)}
                onMoveDown={() => store.moveQueueItem(absIdx, absIdx + 1)}
                canMoveUp={idx > 0}
                canMoveDown={idx < upNext.length - 1}
                onRemove={() => {
                  void store.removeQueueItem(absIdx);
                }}
              />
            );
          })
        )}
      </ScrollView>
    </View>
  );
}

export function QueueModal() {
  const { queueOpen, setQueueOpen } = usePlayerStore();
  const { colors } = useTheme();

  if (!queueOpen) return null;

  return (
    <Modal
      visible={queueOpen}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={() => setQueueOpen(false)}
    >
      <SafeAreaView style={[styles.modalRoot, { backgroundColor: colors.surface }]}>
        <QueueContent onClose={() => setQueueOpen(false)} />
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalRoot: {
    flex: 1,
  },
  panel: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: layoutTokens.hairline,
  },
  headerControls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  togglePill: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: radii.pill,
    gap: spacing.xxs / 2,
  },
  oneBadge: {
    fontWeight: '700',
  },
  scrollContent: {
    padding: spacing.lg,
    gap: spacing.sm,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: spacing.sm,
  },
  sectionLabel: {
    fontWeight: '700',
    letterSpacing: 0.5,
    marginTop: spacing.xs,
  },
  emptySub: {
    paddingVertical: spacing.xs,
  },
  nowPlayingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: radii.card,
  },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.xs,
    borderBottomWidth: layoutTokens.hairline,
    gap: spacing.xs,
  },
  itemMain: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  thumbWrap: {
    width: layoutTokens.artMini,
    height: layoutTokens.artMini,
    borderRadius: radii.artSmall,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  thumb: {
    width: '100%',
    height: '100%',
  },
  itemText: {
    flex: 1,
    gap: spacing.xxs / 2,
  },
  itemTitle: {
    fontWeight: '600',
  },
  itemActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xxs,
  },
});
