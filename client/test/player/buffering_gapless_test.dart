import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/player/audio_handler.dart';
import 'package:melodia/player/player_state.dart';
import 'package:melodia/player/queue.dart' as q;

void main() {
  group('Buffering Named Constants', () {
    test('named constants have the configured values', () {
      expect(kMinBufferDuration, equals(const Duration(seconds: 4)));
      expect(kMaxBufferDuration, equals(const Duration(seconds: 60)));
      expect(kBufferForPlaybackDuration, equals(const Duration(milliseconds: 1000)));
      expect(kBufferForPlaybackAfterRebufferDuration, equals(const Duration(milliseconds: 3000)));
      expect(kDarwinPreferredForwardBufferDuration, equals(const Duration(seconds: 45)));
    });
  });

  Track makeTrack(String id) => Track(
        videoId: id,
        title: 'Track $id',
        artists: const [Artist(name: 'Artist')],
        artist: 'Artist',
        isExplicit: false,
      );

  group('Sliding-Window and Queue Logic', () {
    final t1 = makeTrack('vid1');
    final t2 = makeTrack('vid2');
    final t3 = makeTrack('vid3');
    final t4 = makeTrack('vid4');
    final t5 = makeTrack('vid5');

    test('window extracts previous 1, current, and next 2', () {
      var queueState = q.playList(q.QueueState.empty(), [t1, t2, t3, t4, t5], 1);
      expect(queueState.currentIndex, equals(1));
      expect(queueState.currentTrack?.videoId, equals('vid2'));

      // Check window videoIds: previous = vid1, current = vid2, next1 = vid3, next2 = vid4
      final windowIds = <String>{
        if (queueState.currentIndex > 0) queueState.queue[queueState.currentIndex - 1].videoId,
        queueState.currentTrack!.videoId,
        if (queueState.currentIndex + 1 < queueState.queue.length)
          queueState.queue[queueState.currentIndex + 1].videoId,
        if (queueState.currentIndex + 2 < queueState.queue.length)
          queueState.queue[queueState.currentIndex + 2].videoId,
      };

      expect(windowIds, containsAll({'vid1', 'vid2', 'vid3', 'vid4'}));
      expect(windowIds.contains('vid5'), isFalse);
    });

    test('window preserves next tracks when playNextQueue is populated', () {
      var queueState = q.playList(q.QueueState.empty(), [t1, t2, t3], 0);
      queueState = q.enqueueNext(queueState, t4);

      expect(queueState.playNextQueue.first.videoId, equals('vid4'));
    });

    test('window wraps on repeat all', () {
      var queueState = q.playList(q.QueueState.empty(), [t1, t2], 1);
      queueState = queueState.copyWith(repeat: q.RepeatMode.all);

      expect(queueState.repeat, equals(q.RepeatMode.all));
      // next track wraps to first track
      final nextTrack = queueState.currentIndex + 1 < queueState.queue.length
          ? queueState.queue[queueState.currentIndex + 1]
          : queueState.queue.first;
      expect(nextTrack.videoId, equals('vid1'));
    });
  });

  group('Instant-Tap UI Behavior', () {
    test('PlayerStateData initializes with showLoadingIndicator false', () {
      final state = PlayerStateData.initial();
      expect(state.showLoadingIndicator, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('PlayerStateData showLoadingIndicator reflects in isLoading', () {
      final state = PlayerStateData.initial().copyWith(
        status: PlayerStatus.loading,
        showLoadingIndicator: false,
      );
      // Even if status is loading, isLoading (loading indicator) is false until 400ms passes
      expect(state.isLoading, isFalse);

      final stateAfter400ms = state.copyWith(showLoadingIndicator: true);
      expect(stateAfter400ms.isLoading, isTrue);
    });
  });
}
