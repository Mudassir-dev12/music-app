import type { Track } from '@/api/types';
import type { RepeatMode } from '@/player/types';

export interface QueueState {
  queue: Track[];
  originalQueue: Track[];
  currentIndex: number;
  activeOverride: Track | null;
  playNext: Track[];
  history: Track[];
  shuffle: boolean;
  repeat: RepeatMode;
}

export const INITIAL_QUEUE_STATE: QueueState = {
  queue: [],
  originalQueue: [],
  currentIndex: -1,
  activeOverride: null,
  playNext: [],
  history: [],
  shuffle: false,
  repeat: 'off',
};

export function getCurrentTrack(state: QueueState): Track | null {
  if (state.activeOverride) {
    return state.activeOverride;
  }
  if (state.currentIndex >= 0 && state.currentIndex < state.queue.length) {
    return state.queue[state.currentIndex];
  }
  return null;
}

export function getUpNext(state: QueueState): Track[] {
  if (state.currentIndex < 0 || state.currentIndex >= state.queue.length) {
    return [];
  }
  return state.queue.slice(state.currentIndex + 1);
}

function fisherYatesShuffle<T>(items: T[], rng: () => number = Math.random): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

export function playList(
  state: QueueState,
  tracks: Track[],
  startIndex = 0,
  rng: () => number = Math.random
): QueueState {
  if (tracks.length === 0) {
    return { ...INITIAL_QUEUE_STATE, shuffle: state.shuffle, repeat: state.repeat };
  }
  const safeIndex = Math.max(0, Math.min(startIndex, tracks.length - 1));
  if (state.shuffle) {
    const selected = tracks[safeIndex];
    const others = tracks.filter((_, idx) => idx !== safeIndex);
    const shuffled = [selected, ...fisherYatesShuffle(others, rng)];
    return {
      ...state,
      queue: shuffled,
      originalQueue: [...tracks],
      currentIndex: 0,
      activeOverride: null,
      playNext: [],
      history: [],
    };
  }

  return {
    ...state,
    queue: [...tracks],
    originalQueue: [],
    currentIndex: safeIndex,
    activeOverride: null,
    playNext: [],
    history: [],
  };
}

export interface StepResult {
  state: QueueState;
  track: Track | null;
  shouldPlay: boolean;
  replayCurrent?: boolean;
}

export function next(state: QueueState, fromTrackEnd = false): StepResult {
  const current = getCurrentTrack(state);

  if (fromTrackEnd && state.repeat === 'one' && current) {
    return {
      state,
      track: current,
      shouldPlay: true,
      replayCurrent: true,
    };
  }

  const nextHistory = current ? [...state.history, current].slice(-100) : state.history;

  // 1. Pop from playNext queue first
  if (state.playNext.length > 0) {
    const [nextUp, ...restPlayNext] = state.playNext;
    return {
      state: {
        ...state,
        activeOverride: nextUp,
        playNext: restPlayNext,
        history: nextHistory,
      },
      track: nextUp,
      shouldPlay: true,
    };
  }

  // 2. Advance main queue
  if (state.queue.length === 0) {
    return {
      state: { ...state, currentIndex: -1, activeOverride: null },
      track: null,
      shouldPlay: false,
    };
  }

  const nextIndex = state.currentIndex + 1;
  if (nextIndex < state.queue.length) {
    const nextTrack = state.queue[nextIndex];
    return {
      state: {
        ...state,
        currentIndex: nextIndex,
        activeOverride: null,
        history: nextHistory,
      },
      track: nextTrack,
      shouldPlay: true,
    };
  }

  // 3. Reached end of queue
  if (state.repeat === 'all') {
    const firstTrack = state.queue[0];
    return {
      state: {
        ...state,
        currentIndex: 0,
        activeOverride: null,
        history: nextHistory,
      },
      track: firstTrack,
      shouldPlay: true,
    };
  }

  // Repeat off: stop and reset to first track paused
  return {
    state: {
      ...state,
      currentIndex: 0,
      activeOverride: null,
    },
    track: state.queue[0],
    shouldPlay: false,
  };
}

export function previous(
  state: QueueState,
  positionSec: number
): StepResult & { seekToStart?: boolean } {
  const current = getCurrentTrack(state);
  if (!current) {
    return { state, track: null, shouldPlay: false };
  }

  // Restart current track if more than 3 seconds in
  if (positionSec > 3) {
    return {
      state,
      track: current,
      shouldPlay: true,
      seekToStart: true,
    };
  }

  if (state.history.length > 0) {
    const prevTrack = state.history[state.history.length - 1];
    const nextHistory = state.history.slice(0, -1);

    // If we are stepping back inside the main queue without override
    if (!state.activeOverride && state.currentIndex > 0 && state.queue[state.currentIndex - 1]?.video_id === prevTrack.video_id) {
      return {
        state: {
          ...state,
          currentIndex: state.currentIndex - 1,
          activeOverride: null,
          history: nextHistory,
        },
        track: prevTrack,
        shouldPlay: true,
      };
    }

    // If current came from playNext override or main queue, step back cleanly
    const prevQueueIdx = state.queue.findIndex((t) => t.video_id === prevTrack.video_id);
    if (prevQueueIdx >= 0 && state.activeOverride) {
      return {
        state: {
          ...state,
          currentIndex: prevQueueIdx,
          activeOverride: null,
          playNext: [current, ...state.playNext],
          history: nextHistory,
        },
        track: prevTrack,
        shouldPlay: true,
      };
    }

    return {
      state: {
        ...state,
        activeOverride: prevTrack,
        history: nextHistory,
      },
      track: prevTrack,
      shouldPlay: true,
    };
  }

  if (state.currentIndex > 0) {
    const prevIdx = state.currentIndex - 1;
    return {
      state: {
        ...state,
        currentIndex: prevIdx,
        activeOverride: null,
      },
      track: state.queue[prevIdx],
      shouldPlay: true,
    };
  }

  return {
    state,
    track: current,
    shouldPlay: true,
    seekToStart: true,
  };
}

export function enqueueNext(state: QueueState, track: Track): QueueState {
  if (!getCurrentTrack(state) && state.queue.length === 0) {
    return playList(state, [track], 0);
  }
  return {
    ...state,
    playNext: [track, ...state.playNext],
  };
}

export function enqueueLast(state: QueueState, track: Track): QueueState {
  if (!getCurrentTrack(state) && state.queue.length === 0) {
    return playList(state, [track], 0);
  }
  return {
    ...state,
    playNext: [...state.playNext, track],
  };
}

export function removeAt(state: QueueState, index: number): QueueState {
  if (index < 0 || index >= state.queue.length) {
    return state;
  }
  const removed = state.queue[index];
  const nextQueue = state.queue.filter((_, i) => i !== index);
  const nextOriginal = state.originalQueue.length
    ? state.originalQueue.filter((t) => t.video_id !== removed.video_id)
    : [];

  if (nextQueue.length === 0) {
    return {
      ...state,
      queue: [],
      originalQueue: [],
      currentIndex: -1,
    };
  }

  let nextIndex = state.currentIndex;
  if (index < state.currentIndex) {
    nextIndex = state.currentIndex - 1;
  } else if (index === state.currentIndex) {
    nextIndex = Math.min(state.currentIndex, nextQueue.length - 1);
  }

  return {
    ...state,
    queue: nextQueue,
    originalQueue: nextOriginal,
    currentIndex: nextIndex,
  };
}

export function move(state: QueueState, from: number, to: number): QueueState {
  if (
    from < 0 ||
    to < 0 ||
    from >= state.queue.length ||
    to >= state.queue.length ||
    from === to
  ) {
    return state;
  }

  const nextQueue = [...state.queue];
  const [item] = nextQueue.splice(from, 1);
  nextQueue.splice(to, 0, item);

  let nextIndex = state.currentIndex;
  if (state.currentIndex === from) {
    nextIndex = to;
  } else if (from < state.currentIndex && to >= state.currentIndex) {
    nextIndex = state.currentIndex - 1;
  } else if (from > state.currentIndex && to <= state.currentIndex) {
    nextIndex = state.currentIndex + 1;
  }

  return {
    ...state,
    queue: nextQueue,
    currentIndex: nextIndex,
  };
}

export function removePlayNextAt(state: QueueState, index: number): QueueState {
  if (index < 0 || index >= state.playNext.length) return state;
  return {
    ...state,
    playNext: state.playNext.filter((_, i) => i !== index),
  };
}

export function movePlayNext(state: QueueState, from: number, to: number): QueueState {
  if (
    from < 0 ||
    to < 0 ||
    from >= state.playNext.length ||
    to >= state.playNext.length ||
    from === to
  ) {
    return state;
  }
  const nextPlayNext = [...state.playNext];
  const [item] = nextPlayNext.splice(from, 1);
  nextPlayNext.splice(to, 0, item);
  return {
    ...state,
    playNext: nextPlayNext,
  };
}

export function clearPlayNext(state: QueueState): QueueState {
  return {
    ...state,
    playNext: [],
  };
}

export function toggleShuffle(
  state: QueueState,
  rng: () => number = Math.random
): QueueState {
  if (!state.shuffle) {
    if (state.queue.length <= 1) {
      return {
        ...state,
        shuffle: true,
        originalQueue: [...state.queue],
      };
    }
    const currentIdx = Math.max(0, state.currentIndex);
    const current = state.queue[currentIdx];
    const others = state.queue.filter((_, idx) => idx !== currentIdx);
    const shuffled = [current, ...fisherYatesShuffle(others, rng)];
    return {
      ...state,
      shuffle: true,
      originalQueue: [...state.queue],
      queue: shuffled,
      currentIndex: 0,
    };
  }

  // Turn shuffle off: restore original order and preserve current track index
  const restored = state.originalQueue.length > 0 ? [...state.originalQueue] : [...state.queue];
  const current =
    state.currentIndex >= 0 && state.currentIndex < state.queue.length
      ? state.queue[state.currentIndex]
      : null;
  let restoredIdx = current
    ? restored.findIndex((t) => t.video_id === current.video_id)
    : 0;
  if (restoredIdx < 0) restoredIdx = 0;

  return {
    ...state,
    shuffle: false,
    queue: restored,
    originalQueue: [],
    currentIndex: restored.length > 0 ? restoredIdx : -1,
  };
}

export function cycleRepeat(state: QueueState): QueueState {
  const order: RepeatMode[] = ['off', 'all', 'one'];
  const idx = order.indexOf(state.repeat);
  return {
    ...state,
    repeat: order[(idx + 1) % order.length],
  };
}
