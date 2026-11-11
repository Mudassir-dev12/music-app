import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';
import { create } from 'zustand';

import { ApiError } from '@/api/client';
import type { Track } from '@/api/types';
import {
  clearAudioTickets,
  createPlayerEngine,
  getAudioUrl,
  invalidateAudioTicket,
  playerEvents,
  warmUpAudioTrack,
} from '@/player';
import {
  clearPlayNext as clearPlayNextPure,
  cycleRepeat as cycleRepeatPure,
  enqueueLast as enqueueLastPure,
  enqueueNext as enqueueNextPure,
  getCurrentTrack,
  INITIAL_QUEUE_STATE,
  move as movePure,
  movePlayNext as movePlayNextPure,
  next as nextPure,
  playList as playListPure,
  previous as previousPure,
  type QueueState,
  removeAt as removeAtPure,
  removePlayNextAt as removePlayNextAtPure,
  toggleShuffle as toggleShufflePure,
} from '@/player/queue';
import type { PlaybackStatus, PlayerEngine, RepeatMode } from '@/player/types';
import { registerSessionCleanup } from '@/store/session';
import { useToastStore } from '@/store/toast';

const PLAYER_STORAGE_KEY = 'melodia.player_state';
const MAX_RECENTLY_PLAYED = 20;

interface PersistedPlayerState {
  queue: Track[];
  originalQueue: Track[];
  currentIndex: number;
  activeOverride: Track | null;
  playNext: Track[];
  shuffle: boolean;
  repeat: RepeatMode;
  volume: number;
  positionSec: number;
  sourceLabel: string;
  recentlyPlayed: Track[];
}

export interface PlayerStoreState extends QueueState {
  isPlaying: boolean;
  status: PlaybackStatus;
  positionSec: number;
  durationSec: number;
  volume: number;
  sourceLabel: string;
  recentlyPlayed: Track[];
  consecutiveErrors: number;
  nowPlayingOpen: boolean;
  queueOpen: boolean;
  hydrated: boolean;

  restore: () => Promise<void>;
  playTracks: (tracks: Track[], startIndex?: number, sourceLabel?: string) => Promise<void>;
  togglePlayPause: () => Promise<void>;
  play: () => Promise<void>;
  pause: () => Promise<void>;
  seek: (seconds: number) => Promise<void>;
  nextTrack: (fromTrackEnd?: boolean) => Promise<void>;
  previousTrack: () => Promise<void>;
  enqueueNext: (track: Track) => Promise<void>;
  enqueueLast: (track: Track) => Promise<void>;
  removeQueueItem: (index: number) => Promise<void>;
  moveQueueItem: (from: number, to: number) => void;
  removePlayNextItem: (index: number) => void;
  movePlayNextItem: (from: number, to: number) => void;
  clearPlayNext: () => void;
  toggleShuffle: () => void;
  cycleRepeat: () => void;
  setVolume: (volume: number) => void;
  setNowPlayingOpen: (open: boolean) => void;
  setQueueOpen: (open: boolean) => void;
  resetOnSignOut: () => void;
}

let engineInstance: PlayerEngine | null = null;
let engineUnsub: (() => void) | null = null;
let persistTimer: ReturnType<typeof setTimeout> | null = null;
let loadGeneration = 0;
let loadedVideoId: string | null = null;
let retriedLoadForVideoId: string | null = null;
let emitted30sForGen = -1;
let lastProgressStoreUpdateMs = 0;

function extractQueueState(s: PlayerStoreState): QueueState {
  return {
    queue: s.queue,
    originalQueue: s.originalQueue,
    currentIndex: s.currentIndex,
    activeOverride: s.activeOverride,
    playNext: s.playNext,
    history: s.history,
    shuffle: s.shuffle,
    repeat: s.repeat,
  };
}

function addRecent(list: Track[], track: Track): Track[] {
  const filtered = list.filter((t) => t.video_id !== track.video_id);
  return [track, ...filtered].slice(0, MAX_RECENTLY_PLAYED);
}

function schedulePersist(state: PlayerStoreState): void {
  if (persistTimer) clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    persistTimer = null;
    const payload: PersistedPlayerState = {
      queue: state.queue,
      originalQueue: state.originalQueue,
      currentIndex: state.currentIndex,
      activeOverride: state.activeOverride,
      playNext: state.playNext,
      shuffle: state.shuffle,
      repeat: state.repeat,
      volume: state.volume,
      positionSec: state.positionSec,
      sourceLabel: state.sourceLabel,
      recentlyPlayed: state.recentlyPlayed,
    };
    AsyncStorage.setItem(PLAYER_STORAGE_KEY, JSON.stringify(payload)).catch(() => {});
  }, 1000);
}

export function __resetPlayerInternalsForTests(): void {
  if (persistTimer) {
    clearTimeout(persistTimer);
    persistTimer = null;
  }
  engineUnsub?.();
  engineUnsub = null;
  engineInstance?.destroy();
  engineInstance = null;
  loadGeneration = 0;
  loadedVideoId = null;
  retriedLoadForVideoId = null;
  emitted30sForGen = -1;
  lastProgressStoreUpdateMs = 0;
}

function ensureEngine(): PlayerEngine {
  if (engineInstance) return engineInstance;
  const eng = createPlayerEngine();
  engineInstance = eng;
  engineUnsub = eng.onEvent((event) => {
    const store = usePlayerStore.getState();
    const current = getCurrentTrack(extractQueueState(store));

    if (event.type === 'state') {
      const isPlaying = event.status === 'playing';
      usePlayerStore.setState({
        status: event.status,
        isPlaying,
        ...(isPlaying ? { consecutiveErrors: 0 } : {}),
      });
      return;
    }

    if (event.type === 'progress') {
      const now = Date.now();
      if (now - lastProgressStoreUpdateMs < 240) {
        return;
      }
      lastProgressStoreUpdateMs = now;
      const durationSec =
        event.durationSec > 0 ? event.durationSec : (current?.duration_seconds ?? store.durationSec);

      usePlayerStore.setState({
        positionSec: event.positionSec,
        durationSec,
      });

      if (current) {
        const halfDuration = durationSec > 0 ? durationSec * 0.5 : Infinity;
        if (
          emitted30sForGen !== loadGeneration &&
          (event.positionSec >= 30 || event.positionSec >= halfDuration)
        ) {
          emitted30sForGen = loadGeneration;
          playerEvents.emit({
            type: 'track-30s',
            track: current,
            positionSec: event.positionSec,
          });
        }

        if (durationSec > 0 && event.positionSec >= durationSec * 0.5) {
          const upcoming = store.playNext[0] ?? store.queue[store.currentIndex + 1];
          if (upcoming) {
            void warmUpAudioTrack(upcoming.video_id);
          }
        }
      }
      schedulePersist(usePlayerStore.getState());
      return;
    }

    if (event.type === 'ended') {
      if (current) {
        playerEvents.emit({ type: 'track-ended', track: current });
      }
      void store.nextTrack(true);
      return;
    }

    if (event.type === 'remote-next') {
      void store.nextTrack(false);
      return;
    }

    if (event.type === 'remote-prev') {
      void store.previousTrack();
      return;
    }

    if (event.type === 'error') {
      void handlePlaybackFailure(event.message, event.statusCode);
    }
  });
  return eng;
}

async function handlePlaybackFailure(message: string, statusCode?: number): Promise<void> {
  const store = usePlayerStore.getState();
  const current = getCurrentTrack(extractQueueState(store));
  if (!current) return;

  if (statusCode === 429) {
    useToastStore
      .getState()
      .show('Bandwidth limit reached. Playback paused until UTC midnight.', 'error', 5000);
    await store.pause();
    return;
  }

  // First failure on this track load: fetch a fresh ticket once and resume at saved position
  if (retriedLoadForVideoId !== current.video_id) {
    retriedLoadForVideoId = current.video_id;
    invalidateAudioTicket(current.video_id);
    await loadTrackIntoEngine(current, {
      autoplay: true,
      startPositionSec: store.positionSec,
      forceFreshTicket: true,
      isRecoveryAttempt: true,
    });
    return;
  }

  // Second failure on same track
  const nextErrors = store.consecutiveErrors + 1;
  useToastStore.getState().show('This song is unavailable', 'error');

  if (nextErrors >= 3) {
    usePlayerStore.setState({
      consecutiveErrors: nextErrors,
      isPlaying: false,
      status: 'error',
    });
    return;
  }

  usePlayerStore.setState({ consecutiveErrors: nextErrors });
  await store.nextTrack(false);
}

async function loadTrackIntoEngine(
  track: Track,
  opts: {
    autoplay: boolean;
    startPositionSec?: number;
    forceFreshTicket?: boolean;
    isRecoveryAttempt?: boolean;
  }
): Promise<void> {
  const gen = ++loadGeneration;
  if (!opts.isRecoveryAttempt) {
    retriedLoadForVideoId = null;
  }
  emitted30sForGen = -1;

  const eng = ensureEngine();
  eng.setVolume(usePlayerStore.getState().volume);

  usePlayerStore.setState((s) => ({
    status: opts.autoplay ? 'loading' : 'paused',
    isPlaying: false,
    positionSec: opts.startPositionSec ?? 0,
    durationSec: track.duration_seconds ?? 0,
    recentlyPlayed: opts.autoplay ? addRecent(s.recentlyPlayed, track) : s.recentlyPlayed,
  }));

  try {
    const url = await getAudioUrl(track.video_id, Boolean(opts.forceFreshTicket));
    if (gen !== loadGeneration) return;

    loadedVideoId = track.video_id;
    if (opts.autoplay) {
      playerEvents.emit({ type: 'track-started', track });
    }
    await eng.load(track, {
      autoplay: opts.autoplay,
      startPositionSec: opts.startPositionSec,
      url,
    });
    schedulePersist(usePlayerStore.getState());
  } catch (err) {
    if (gen !== loadGeneration) return;
    if (err instanceof ApiError && err.status === 429) {
      const resetMsg = err.retryAfterSec
        ? `Bandwidth limit reached. Try again in ${err.retryAfterSec}s.`
        : 'Daily bandwidth limit reached.';
      useToastStore.getState().show(resetMsg, 'error', 5000);
      usePlayerStore.setState({ isPlaying: false, status: 'paused' });
      return;
    }
    await handlePlaybackFailure(
      err instanceof Error ? err.message : 'Unable to load track',
      err instanceof ApiError ? err.status : undefined
    );
  }
}

export const usePlayerStore = create<PlayerStoreState>((set, get) => ({
  ...INITIAL_QUEUE_STATE,
  isPlaying: false,
  status: 'idle',
  positionSec: 0,
  durationSec: 0,
  volume: 0.9,
  sourceLabel: '',
  recentlyPlayed: [],
  consecutiveErrors: 0,
  nowPlayingOpen: false,
  queueOpen: false,
  hydrated: false,

  restore: async () => {
    if (get().hydrated) return;
    try {
      const raw = await AsyncStorage.getItem(PLAYER_STORAGE_KEY);
      if (!raw) {
        set({ hydrated: true });
        return;
      }
      const parsed = JSON.parse(raw) as Partial<PersistedPlayerState>;
      const queue = Array.isArray(parsed.queue) ? parsed.queue : [];
      const currentIndex =
        typeof parsed.currentIndex === 'number' && parsed.currentIndex < queue.length
          ? parsed.currentIndex
          : queue.length > 0
            ? 0
            : -1;
      const currentTrack =
        parsed.activeOverride ?? (currentIndex >= 0 ? queue[currentIndex] : null);

      loadedVideoId = null;
      set({
        queue,
        originalQueue: Array.isArray(parsed.originalQueue) ? parsed.originalQueue : [],
        currentIndex,
        activeOverride: parsed.activeOverride ?? null,
        playNext: Array.isArray(parsed.playNext) ? parsed.playNext : [],
        history: [],
        shuffle: Boolean(parsed.shuffle),
        repeat: parsed.repeat === 'all' || parsed.repeat === 'one' ? parsed.repeat : 'off',
        volume: typeof parsed.volume === 'number' ? Math.min(1, Math.max(0, parsed.volume)) : 0.9,
        positionSec: typeof parsed.positionSec === 'number' ? Math.max(0, parsed.positionSec) : 0,
        durationSec: currentTrack?.duration_seconds ?? 0,
        sourceLabel: typeof parsed.sourceLabel === 'string' ? parsed.sourceLabel : '',
        recentlyPlayed: Array.isArray(parsed.recentlyPlayed) ? parsed.recentlyPlayed : [],
        isPlaying: false,
        status: currentTrack ? 'paused' : 'idle',
        hydrated: true,
      });
    } catch {
      set({ hydrated: true });
    }
  },

  playTracks: async (tracks, startIndex = 0, sourceLabel = 'Search') => {
    const nextQ = playListPure(extractQueueState(get()), tracks, startIndex);
    set({
      ...nextQ,
      sourceLabel,
      consecutiveErrors: 0,
    });
    const current = getCurrentTrack(nextQ);
    if (current) {
      await loadTrackIntoEngine(current, { autoplay: true, startPositionSec: 0 });
    }
  },

  togglePlayPause: async () => {
    if (Platform.OS !== 'web') {
      void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    const s = get();
    if (s.isPlaying) {
      await s.pause();
    } else {
      await s.play();
    }
  },

  play: async () => {
    const s = get();
    const current = getCurrentTrack(extractQueueState(s));
    if (!current) return;

    if (loadedVideoId !== current.video_id) {
      await loadTrackIntoEngine(current, {
        autoplay: true,
        startPositionSec: s.positionSec,
      });
      return;
    }

    await ensureEngine().play();
    set({ isPlaying: true, status: 'playing', consecutiveErrors: 0 });
  },

  pause: async () => {
    await ensureEngine().pause();
    set({ isPlaying: false, status: getCurrentTrack(extractQueueState(get())) ? 'paused' : 'idle' });
    schedulePersist(get());
  },

  seek: async (seconds) => {
    const s = get();
    const clamped = Math.max(0, Math.min(seconds, s.durationSec || seconds));
    set({ positionSec: clamped });
    await ensureEngine().seek(clamped);
    schedulePersist(get());
  },

  nextTrack: async (fromTrackEnd = false) => {
    const res = nextPure(extractQueueState(get()), fromTrackEnd);
    set({ ...res.state });
    if (!res.track) {
      set({ isPlaying: false, status: 'idle', positionSec: 0, durationSec: 0 });
      schedulePersist(get());
      return;
    }
    if (res.replayCurrent) {
      await ensureEngine().seek(0);
      await ensureEngine().play();
      set({ positionSec: 0, isPlaying: true, status: 'playing' });
      schedulePersist(get());
      return;
    }
    await loadTrackIntoEngine(res.track, {
      autoplay: res.shouldPlay,
      startPositionSec: 0,
    });
  },

  previousTrack: async () => {
    const s = get();
    const res = previousPure(extractQueueState(s), s.positionSec);
    set({ ...res.state });
    if (!res.track) return;

    if (res.seekToStart) {
      set({ positionSec: 0 });
      if (loadedVideoId === res.track.video_id) {
        await ensureEngine().seek(0);
        await ensureEngine().play();
      } else {
        await loadTrackIntoEngine(res.track, { autoplay: true, startPositionSec: 0 });
      }
      schedulePersist(get());
      return;
    }

    await loadTrackIntoEngine(res.track, { autoplay: res.shouldPlay, startPositionSec: 0 });
  },

  enqueueNext: async (track) => {
    const wasEmpty = !getCurrentTrack(extractQueueState(get()));
    const nextQ = enqueueNextPure(extractQueueState(get()), track);
    set({ ...nextQ });
    schedulePersist(get());
    if (wasEmpty) {
      const current = getCurrentTrack(nextQ);
      if (current) {
        await loadTrackIntoEngine(current, { autoplay: true, startPositionSec: 0 });
      }
    } else {
      useToastStore.getState().show(`Playing "${track.title}" next`, 'success');
    }
  },

  enqueueLast: async (track) => {
    const wasEmpty = !getCurrentTrack(extractQueueState(get()));
    const nextQ = enqueueLastPure(extractQueueState(get()), track);
    set({ ...nextQ });
    schedulePersist(get());
    if (wasEmpty) {
      const current = getCurrentTrack(nextQ);
      if (current) {
        await loadTrackIntoEngine(current, { autoplay: true, startPositionSec: 0 });
      }
    } else {
      useToastStore.getState().show(`Added "${track.title}" to queue`, 'success');
    }
  },

  removeQueueItem: async (index) => {
    const prevState = extractQueueState(get());
    const removingCurrent = !prevState.activeOverride && index === prevState.currentIndex;
    const nextQ = removeAtPure(prevState, index);
    set({ ...nextQ });
    schedulePersist(get());
    if (removingCurrent) {
      const nextCurrent = getCurrentTrack(nextQ);
      if (nextCurrent) {
        await loadTrackIntoEngine(nextCurrent, { autoplay: get().isPlaying, startPositionSec: 0 });
      } else {
        await ensureEngine().pause();
        loadedVideoId = null;
        set({ isPlaying: false, status: 'idle', positionSec: 0, durationSec: 0 });
      }
    }
  },

  moveQueueItem: (from, to) => {
    const nextQ = movePure(extractQueueState(get()), from, to);
    set({ ...nextQ });
    schedulePersist(get());
  },

  removePlayNextItem: (index) => {
    const nextQ = removePlayNextAtPure(extractQueueState(get()), index);
    set({ ...nextQ });
    schedulePersist(get());
  },

  movePlayNextItem: (from, to) => {
    const nextQ = movePlayNextPure(extractQueueState(get()), from, to);
    set({ ...nextQ });
    schedulePersist(get());
  },

  clearPlayNext: () => {
    const nextQ = clearPlayNextPure(extractQueueState(get()));
    set({ ...nextQ });
    schedulePersist(get());
  },

  toggleShuffle: () => {
    const nextQ = toggleShufflePure(extractQueueState(get()));
    set({ ...nextQ });
    schedulePersist(get());
  },

  cycleRepeat: () => {
    const nextQ = cycleRepeatPure(extractQueueState(get()));
    set({ ...nextQ });
    schedulePersist(get());
  },

  setVolume: (volume) => {
    const clamped = Math.min(1, Math.max(0, volume));
    ensureEngine().setVolume(clamped);
    set({ volume: clamped });
    schedulePersist(get());
  },

  setNowPlayingOpen: (open) => set({ nowPlayingOpen: open }),
  setQueueOpen: (open) => set({ queueOpen: open }),

  resetOnSignOut: () => {
    loadGeneration++;
    loadedVideoId = null;
    retriedLoadForVideoId = null;
    emitted30sForGen = -1;
    clearAudioTickets();
    if (persistTimer) {
      clearTimeout(persistTimer);
      persistTimer = null;
    }
    engineUnsub?.();
    engineUnsub = null;
    engineInstance?.destroy();
    engineInstance = null;
    AsyncStorage.removeItem(PLAYER_STORAGE_KEY).catch(() => {});
    set({
      ...INITIAL_QUEUE_STATE,
      isPlaying: false,
      status: 'idle',
      positionSec: 0,
      durationSec: 0,
      sourceLabel: '',
      recentlyPlayed: [],
      consecutiveErrors: 0,
      nowPlayingOpen: false,
      queueOpen: false,
    });
  },
}));

registerSessionCleanup(() => {
  usePlayerStore.getState().resetOnSignOut();
});

