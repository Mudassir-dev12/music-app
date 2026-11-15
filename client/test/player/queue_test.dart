// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/player/queue.dart';
import 'package:melodia/api/models.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Track makeTrack(String id) => Track(
      videoId: id,
      title: 'Track $id',
      artists: const [Artist(name: 'Artist')],
      artist: 'Artist',
      album: 'Album',
      albumId: 'album1',
      durationSeconds: 200,
      thumbnail: 'https://example.com/$id.jpg',
      isExplicit: false,
    );

List<Track> makeTracks(int n) =>
    List.generate(n, (i) => makeTrack('t${i + 1}'));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('playList', () {
    test('sets correct currentIndex and clears history', () {
      final tracks = makeTracks(5);
      final initial = QueueState.empty().copyWith(
        history: [makeTrack('old')],
        playNextQueue: [makeTrack('pnq')],
      );
      final state = playList(initial, tracks, 2);

      expect(state.queue, equals(tracks));
      expect(state.currentIndex, equals(2));
      expect(state.currentTrack, equals(tracks[2]));
      expect(state.history, isEmpty);
      expect(state.playNextQueue, isEmpty);
    });

    test('clamps startIndex within bounds', () {
      final tracks = makeTracks(3);
      final state = playList(QueueState.empty(), tracks, 10);
      expect(state.currentIndex, equals(2));
    });

    test('when shuffle on, current track is at index 0', () {
      final tracks = makeTracks(5);
      final initial = QueueState.empty().copyWith(shuffle: true);
      final state = playList(initial, tracks, 2);

      expect(state.currentIndex, equals(0));
      expect(state.currentTrack, equals(tracks[2]));
      expect(state.queue.length, equals(5));
    });
  });

  // -------------------------------------------------------------------------

  group('nextTrack', () {
    test('advances index normally', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 0);
      state = nextTrack(state);
      expect(state.currentIndex, equals(1));
      expect(state.history.length, equals(1));
    });

    test('repeat=off at end: signals stopped (currentIndex=-1)', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 2);
      state = nextTrack(state);
      expect(state.currentIndex, equals(-1));
      expect(state.currentTrack, isNull);
    });

    test('repeat=all at end: wraps to 0', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 2);
      state = cycleRepeat(state); // off → all
      state = nextTrack(state);
      expect(state.currentIndex, equals(0));
      expect(state.currentTrack, equals(tracks[0]));
    });

    test('repeat=one: stays at same index', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 1);
      state = cycleRepeat(state); // off → all
      state = cycleRepeat(state); // all → one
      state = nextTrack(state);
      expect(state.currentIndex, equals(1));
      expect(state.history, isEmpty); // history not added for repeat=one
    });

    test('playNextQueue: dequeues first item and inserts into queue', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 0);
      final pnq = makeTrack('pnq');
      state = enqueueNext(state, pnq);
      expect(state.playNextQueue, equals([pnq]));

      state = nextTrack(state);
      expect(state.currentTrack, equals(pnq));
      expect(state.playNextQueue, isEmpty);
      expect(state.queue.length, equals(4)); // pnq inserted into queue
    });

    test('history capped at 50 items', () {
      // Build state with 49 items in history
      final tracks = makeTracks(55);
      var state = playList(QueueState.empty(), tracks, 0);
      // Advance 51 times to push history past 50
      for (int i = 0; i < 51; i++) {
        state = nextTrack(state);
      }
      expect(state.history.length, lessThanOrEqualTo(50));
    });

    test('adds old currentTrack to history on advance', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 0);
      final first = state.currentTrack!;
      state = nextTrack(state);
      expect(state.history, contains(first));
    });
  });

  // -------------------------------------------------------------------------

  group('previousTrack', () {
    test('position > 3s: restarts same track (same index)', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 2);
      final before = state.currentIndex;
      state = previousTrack(state, const Duration(seconds: 5));
      expect(state.currentIndex, equals(before));
      expect(state.history, isEmpty);
    });

    test('position <= 3s: goes to previous track', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 2);
      state = previousTrack(state, const Duration(seconds: 2));
      expect(state.currentIndex, equals(1));
    });

    test('at start, repeat=off: stays at 0', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 0);
      state = previousTrack(state, const Duration(seconds: 1));
      expect(state.currentIndex, equals(0));
    });

    test('at start, repeat=all: wraps to last', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 0);
      state = cycleRepeat(state); // off → all
      state = previousTrack(state, const Duration(seconds: 1));
      expect(state.currentIndex, equals(tracks.length - 1));
    });

    test('going back adds current to history', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 2);
      final current = state.currentTrack!;
      state = previousTrack(state, const Duration(seconds: 1));
      expect(state.history, contains(current));
    });
  });

  // -------------------------------------------------------------------------

  group('enqueueNext', () {
    test('adds track to front of playNextQueue', () {
      var state = QueueState.empty();
      final a = makeTrack('a');
      final b = makeTrack('b');
      state = enqueueNext(state, a);
      state = enqueueNext(state, b);
      expect(state.playNextQueue.first, equals(b));
      expect(state.playNextQueue.last, equals(a));
    });
  });

  // -------------------------------------------------------------------------

  group('enqueueLast', () {
    test('adds track to end of queue', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 0);
      final extra = makeTrack('extra');
      state = enqueueLast(state, extra);
      expect(state.queue.last, equals(extra));
      expect(state.queue.length, equals(4));
    });
  });

  // -------------------------------------------------------------------------

  group('removeAt', () {
    test('removes track not at currentIndex (before)', () {
      final tracks = makeTracks(4);
      var state = playList(QueueState.empty(), tracks, 2);
      state = removeAt(state, 0);
      expect(state.queue.length, equals(3));
      expect(state.currentIndex, equals(1)); // shifted down
    });

    test('removes track not at currentIndex (after)', () {
      final tracks = makeTracks(4);
      var state = playList(QueueState.empty(), tracks, 1);
      state = removeAt(state, 3);
      expect(state.queue.length, equals(3));
      expect(state.currentIndex, equals(1)); // unchanged
    });

    test('removes currentIndex track: next track becomes current', () {
      final tracks = makeTracks(4);
      var state = playList(QueueState.empty(), tracks, 1);
      final expectedNext = tracks[2]; // was at index 2, now at index 1
      state = removeAt(state, 1);
      expect(state.currentIndex, equals(1));
      expect(state.currentTrack, equals(expectedNext));
    });

    test('removes last item when queue size=1: stops', () {
      final tracks = [makeTrack('only')];
      var state = playList(QueueState.empty(), tracks, 0);
      state = removeAt(state, 0);
      expect(state.queue, isEmpty);
      expect(state.currentIndex, equals(-1));
    });

    test('removes currentIndex at last position: clamps', () {
      final tracks = makeTracks(3);
      var state = playList(QueueState.empty(), tracks, 2); // last
      state = removeAt(state, 2);
      expect(state.currentIndex, equals(1)); // clamped to new last
    });
  });

  // -------------------------------------------------------------------------

  group('move', () {
    test('no-op when from == to', () {
      final tracks = makeTracks(4);
      var state = playList(QueueState.empty(), tracks, 1);
      final before = state.copyWith();
      state = move(state, 2, 2);
      expect(state.currentIndex, equals(before.currentIndex));
    });

    test('moves item and adjusts currentIndex when item crosses it (from < current, to >= current)', () {
      final tracks = makeTracks(5);
      // current=2; move item from 0 → 3 (crosses current)
      var state = playList(QueueState.empty(), tracks, 2);
      state = move(state, 0, 3);
      // item from before current moved past it → currentIndex shifts down by 1
      expect(state.currentIndex, equals(1));
    });

    test('moves item and adjusts currentIndex when item crosses it (from > current, to <= current)', () {
      final tracks = makeTracks(5);
      // current=2; move item from 4 → 1 (crosses current)
      var state = playList(QueueState.empty(), tracks, 2);
      state = move(state, 4, 1);
      // item from after current moved before it → currentIndex shifts up by 1
      expect(state.currentIndex, equals(3));
    });

    test('moving currentIndex item: currentIndex follows', () {
      final tracks = makeTracks(5);
      var state = playList(QueueState.empty(), tracks, 2);
      state = move(state, 2, 4);
      expect(state.currentIndex, equals(4));
      expect(state.currentTrack, equals(tracks[2]));
    });
  });

  // -------------------------------------------------------------------------

  group('toggleShuffle', () {
    test('enable: current track stays at index 0, others shuffled', () {
      final tracks = makeTracks(5);
      var state = playList(QueueState.empty(), tracks, 2);
      final current = state.currentTrack!;
      state = toggleShuffle(state);

      expect(state.shuffle, isTrue);
      expect(state.currentIndex, equals(0));
      expect(state.currentTrack, equals(current));
      expect(state.queue.length, equals(5));
      // All tracks still present
      for (final t in tracks) {
        expect(state.queue, contains(t));
      }
    });

    test('disable: original order restored, currentIndex updated', () {
      final tracks = makeTracks(5);
      var state = playList(QueueState.empty(), tracks, 2);
      final current = state.currentTrack!; // tracks[2]
      state = toggleShuffle(state); // enable
      state = toggleShuffle(state); // disable

      expect(state.shuffle, isFalse);
      expect(state.queue, equals(tracks));
      // current track found in original order at index 2
      expect(state.currentIndex, equals(2));
      expect(state.currentTrack, equals(current));
    });

    test('enable on empty queue: no crash', () {
      var state = QueueState.empty();
      state = toggleShuffle(state);
      expect(state.shuffle, isTrue);
      expect(state.queue, isEmpty);
    });
  });

  // -------------------------------------------------------------------------

  group('cycleRepeat', () {
    test('cycles off → all → one → off', () {
      var state = QueueState.empty();
      expect(state.repeat, equals(RepeatMode.off));

      state = cycleRepeat(state);
      expect(state.repeat, equals(RepeatMode.all));

      state = cycleRepeat(state);
      expect(state.repeat, equals(RepeatMode.one));

      state = cycleRepeat(state);
      expect(state.repeat, equals(RepeatMode.off));
    });
  });

  // -------------------------------------------------------------------------

  group('history', () {
    test('history is added in order of play', () {
      final tracks = makeTracks(4);
      var state = playList(QueueState.empty(), tracks, 0);
      state = nextTrack(state); // plays tracks[0], advances to tracks[1]
      state = nextTrack(state); // plays tracks[1], advances to tracks[2]

      expect(state.history[0], equals(tracks[0]));
      expect(state.history[1], equals(tracks[1]));
    });

    test('history capped at 50 entries', () {
      final tracks = makeTracks(60);
      var state = playList(QueueState.empty(), tracks, 0);
      for (int i = 0; i < 55; i++) {
        state = nextTrack(state);
      }
      expect(state.history.length, lessThanOrEqualTo(50));
    });
  });
}
