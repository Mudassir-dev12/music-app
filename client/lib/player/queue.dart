// Pure Dart queue logic — no Flutter dependencies
import 'dart:math';
import '../api/models.dart';

// ---------------------------------------------------------------------------
// RepeatMode
// ---------------------------------------------------------------------------

enum RepeatMode { off, all, one }

// ---------------------------------------------------------------------------
// QueueState
// ---------------------------------------------------------------------------

class QueueState {
  const QueueState({
    required this.queue,
    required this.currentIndex,
    required this.playNextQueue,
    required this.history,
    required this.shuffle,
    required this.repeat,
    required List<Track> originalOrder,
  }) : _originalOrder = originalOrder;

  final List<Track> queue;
  final int currentIndex;
  final List<Track> playNextQueue;
  final List<Track> history;
  final bool shuffle;
  final RepeatMode repeat;
  final List<Track> _originalOrder;

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  bool get isEmpty => queue.isEmpty;
  bool get isNotEmpty => queue.isNotEmpty;

  QueueState copyWith({
    List<Track>? queue,
    int? currentIndex,
    List<Track>? playNextQueue,
    List<Track>? history,
    bool? shuffle,
    RepeatMode? repeat,
    List<Track>? originalOrder,
  }) {
    return QueueState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playNextQueue: playNextQueue ?? this.playNextQueue,
      history: history ?? this.history,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      originalOrder: originalOrder ?? _originalOrder,
    );
  }

  static QueueState empty() => const QueueState(
        queue: [],
        currentIndex: -1,
        playNextQueue: [],
        history: [],
        shuffle: false,
        repeat: RepeatMode.off,
        originalOrder: [],
      );
}

// ---------------------------------------------------------------------------
// Helper: Fisher-Yates shuffle
// ---------------------------------------------------------------------------

List<T> _shuffled<T>(List<T> list, [Random? rng]) {
  final r = rng ?? Random();
  final copy = List<T>.of(list);
  for (var i = copy.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  return copy;
}

List<Track> _addToHistory(List<Track> history, Track track) {
  final next = [...history, track];
  if (next.length > 50) return next.sublist(next.length - 50);
  return next;
}

// ---------------------------------------------------------------------------
// 1. playList
// ---------------------------------------------------------------------------

QueueState playList(
  QueueState state,
  List<Track> tracks,
  int startIndex,
) {
  if (tracks.isEmpty) return state;
  final clampedIndex = startIndex.clamp(0, tracks.length - 1);

  if (!state.shuffle) {
    return state.copyWith(
      queue: List.unmodifiable(tracks),
      currentIndex: clampedIndex,
      playNextQueue: const [],
      history: const [],
      originalOrder: List.unmodifiable(tracks),
    );
  }

  // Shuffle enabled: preserve current track (at startIndex) at index 0 of queue.
  final current = tracks[clampedIndex];
  final rest = [
    ...tracks.sublist(0, clampedIndex),
    ...tracks.sublist(clampedIndex + 1),
  ];
  final shuffledRest = _shuffled(rest);
  final newQueue = [current, ...shuffledRest];

  return state.copyWith(
    queue: List.unmodifiable(newQueue),
    currentIndex: 0,
    playNextQueue: const [],
    history: const [],
    originalOrder: List.unmodifiable(tracks),
  );
}

// ---------------------------------------------------------------------------
// 2. nextTrack
// ---------------------------------------------------------------------------

QueueState nextTrack(QueueState state) {
  if (state.isEmpty) return state;

  // repeat=one: stay at same index
  if (state.repeat == RepeatMode.one) {
    return state;
  }

  final oldTrack = state.currentTrack;
  List<Track> newHistory = state.history;
  if (oldTrack != null) {
    newHistory = _addToHistory(state.history, oldTrack);
  }

  // playNextQueue has priority
  if (state.playNextQueue.isNotEmpty) {
    final nextTrackItem = state.playNextQueue.first;
    final newPlayNextQueue = state.playNextQueue.sublist(1);
    // Insert at currentIndex+1 in queue, then advance index
    final insertAt = (state.currentIndex + 1).clamp(0, state.queue.length);
    final newQueue = [
      ...state.queue.sublist(0, insertAt),
      nextTrackItem,
      ...state.queue.sublist(insertAt),
    ];
    return state.copyWith(
      queue: List.unmodifiable(newQueue),
      currentIndex: insertAt,
      playNextQueue: List.unmodifiable(newPlayNextQueue),
      history: List.unmodifiable(newHistory),
    );
  }

  // Normal advance
  if (state.currentIndex < state.queue.length - 1) {
    return state.copyWith(
      currentIndex: state.currentIndex + 1,
      history: List.unmodifiable(newHistory),
    );
  }

  // At end of queue
  if (state.repeat == RepeatMode.all) {
    return state.copyWith(
      currentIndex: 0,
      history: List.unmodifiable(newHistory),
    );
  }

  // repeat=off, at end → signal stopped (currentIndex=-1)
  return state.copyWith(
    currentIndex: -1,
    history: List.unmodifiable(newHistory),
  );
}

// ---------------------------------------------------------------------------
// 3. previousTrack
// ---------------------------------------------------------------------------

QueueState previousTrack(QueueState state, Duration position) {
  if (state.isEmpty) return state;

  // Position > 3s: restart same track
  if (position.inMilliseconds > 3000) {
    return state;
  }

  // Go to previous track
  if (state.currentIndex > 0) {
    final oldTrack = state.currentTrack;
    List<Track> newHistory = state.history;
    if (oldTrack != null) {
      newHistory = _addToHistory(state.history, oldTrack);
    }
    return state.copyWith(
      currentIndex: state.currentIndex - 1,
      history: List.unmodifiable(newHistory),
    );
  }

  // At start of queue
  if (state.repeat == RepeatMode.all) {
    final oldTrack = state.currentTrack;
    List<Track> newHistory = state.history;
    if (oldTrack != null) {
      newHistory = _addToHistory(state.history, oldTrack);
    }
    return state.copyWith(
      currentIndex: state.queue.length - 1,
      history: List.unmodifiable(newHistory),
    );
  }

  // Stay at start
  return state;
}

// ---------------------------------------------------------------------------
// 4. enqueueNext
// ---------------------------------------------------------------------------

QueueState enqueueNext(QueueState state, Track track) {
  return state.copyWith(
    playNextQueue: List.unmodifiable([track, ...state.playNextQueue]),
  );
}

// ---------------------------------------------------------------------------
// 5. enqueueLast
// ---------------------------------------------------------------------------

QueueState enqueueLast(QueueState state, Track track) {
  return state.copyWith(
    queue: List.unmodifiable([...state.queue, track]),
  );
}

// ---------------------------------------------------------------------------
// 6. removeAt
// ---------------------------------------------------------------------------

QueueState removeAt(QueueState state, int index) {
  if (index < 0 || index >= state.queue.length) return state;

  final newQueue = [
    ...state.queue.sublist(0, index),
    ...state.queue.sublist(index + 1),
  ];

  if (newQueue.isEmpty) {
    return state.copyWith(
      queue: const [],
      currentIndex: -1,
    );
  }

  int newIndex = state.currentIndex;

  if (index == state.currentIndex) {
    // Removed the current track: next track takes over (or clamp to last)
    newIndex = index < newQueue.length ? index : newQueue.length - 1;
  } else if (index < state.currentIndex) {
    // Removed before current: shift index down
    newIndex = state.currentIndex - 1;
  }

  return state.copyWith(
    queue: List.unmodifiable(newQueue),
    currentIndex: newIndex,
  );
}

// ---------------------------------------------------------------------------
// 7. move
// ---------------------------------------------------------------------------

QueueState move(QueueState state, int from, int to) {
  if (from == to) return state;
  if (from < 0 || from >= state.queue.length) return state;
  if (to < 0 || to >= state.queue.length) return state;

  final newQueue = List<Track>.of(state.queue);
  final item = newQueue.removeAt(from);
  newQueue.insert(to, item);

  int newCurrentIndex = state.currentIndex;
  if (from == state.currentIndex) {
    newCurrentIndex = to;
  } else if (from < state.currentIndex && to >= state.currentIndex) {
    newCurrentIndex = state.currentIndex - 1;
  } else if (from > state.currentIndex && to <= state.currentIndex) {
    newCurrentIndex = state.currentIndex + 1;
  }

  return state.copyWith(
    queue: List.unmodifiable(newQueue),
    currentIndex: newCurrentIndex,
  );
}

// ---------------------------------------------------------------------------
// 8. toggleShuffle
// ---------------------------------------------------------------------------

QueueState toggleShuffle(QueueState state) {
  if (!state.shuffle) {
    // Enabling shuffle: preserve current track at index 0 of remaining tracks
    final current = state.currentTrack;
    if (current == null || state.queue.isEmpty) {
      return state.copyWith(
        shuffle: true,
        originalOrder: List.unmodifiable(state.queue),
      );
    }

    final rest = [
      ...state.queue.sublist(0, state.currentIndex),
      ...state.queue.sublist(state.currentIndex + 1),
    ];
    final shuffledRest = _shuffled(rest);
    final newQueue = [current, ...shuffledRest];

    return state.copyWith(
      shuffle: true,
      queue: List.unmodifiable(newQueue),
      currentIndex: 0,
      originalOrder: List.unmodifiable(state.queue),
    );
  } else {
    // Disabling shuffle: restore original order, find current track
    final original = state._originalOrder;
    if (original.isEmpty) {
      return state.copyWith(
        shuffle: false,
        queue: const [],
        currentIndex: -1,
        originalOrder: const [],
      );
    }

    final current = state.currentTrack;
    int newIndex = -1;
    if (current != null) {
      newIndex = original.indexWhere((t) => t.videoId == current.videoId);
    }

    return state.copyWith(
      shuffle: false,
      queue: List.unmodifiable(original),
      currentIndex: newIndex,
      originalOrder: const [],
    );
  }
}

// ---------------------------------------------------------------------------
// 9. cycleRepeat
// ---------------------------------------------------------------------------

QueueState cycleRepeat(QueueState state) {
  final RepeatMode next;
  switch (state.repeat) {
    case RepeatMode.off:
      next = RepeatMode.all;
    case RepeatMode.all:
      next = RepeatMode.one;
    case RepeatMode.one:
      next = RepeatMode.off;
  }
  return state.copyWith(repeat: next);
}
