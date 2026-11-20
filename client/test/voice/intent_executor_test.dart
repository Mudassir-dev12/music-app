import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/player/queue.dart' as q;
import 'package:melodia/player/sleep_timer.dart';
import 'package:melodia/voice/entity_matcher.dart';
import 'package:melodia/voice/intent_executor.dart';
import 'package:melodia/voice/voice_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntityMatcher', () {
    final now = DateTime.now();
    final playlists = [
      Playlist(
        id: '1',
        name: 'Gym Workout',
        trackCount: 10,
        durationSeconds: 1800,
        coverThumbnails: const [],
        createdAt: now,
        updatedAt: now,
      ),
      Playlist(
        id: '2',
        name: 'Chill Vibes',
        trackCount: 5,
        durationSeconds: 900,
        coverThumbnails: const [],
        createdAt: now,
        updatedAt: now,
      ),
      Playlist(
        id: '3',
        name: 'Road Trip Hindi',
        trackCount: 20,
        durationSeconds: 3600,
        coverThumbnails: const [],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('exact match gets 1.0 score', () {
      final matches = EntityMatcher.matchPlaylist('Gym Workout', playlists);
      expect(matches, isNotEmpty);
      expect(matches.first.item.id, equals('1'));
      expect(matches.first.score, equals(1.0));
    });

    test('case-insensitive match', () {
      final matches = EntityMatcher.matchPlaylist('chill vibes', playlists);
      expect(matches, isNotEmpty);
      expect(matches.first.item.id, equals('2'));
    });

    test('partial / prefix match', () {
      final matches = EntityMatcher.matchPlaylist('Road Trip', playlists);
      expect(matches, isNotEmpty);
      expect(matches.first.item.id, equals('3'));
    });

    test('no match returns empty', () {
      final matches = EntityMatcher.matchPlaylist('Classical Piano', playlists);
      expect(matches, isEmpty);
    });

    test('requiresDisambiguation evaluates score difference', () {
      const c1 = MatchedEntity<String>(item: 'a', score: 0.85, name: 'A');
      const c2 = MatchedEntity<String>(item: 'b', score: 0.82, name: 'B');
      expect(EntityMatcher.requiresDisambiguation(candidates: [c1, c2]), isTrue);

      const c3 = MatchedEntity<String>(item: 'c', score: 0.5, name: 'C');
      expect(EntityMatcher.requiresDisambiguation(candidates: [c1, c3]), isFalse);
    });
  });

  group('SleepTimerController', () {
    test('starts and cancels timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(sleepTimerProvider.notifier);
      controller.start(const Duration(minutes: 20));

      final state = container.read(sleepTimerProvider);
      expect(state.isActive, isTrue);
      expect(state.remainingMinutes, equals(20));

      controller.cancel();
      final afterCancel = container.read(sleepTimerProvider);
      expect(afterCancel.isActive, isFalse);
      expect(afterCancel.remaining, isNull);
    });
  });

  group('IntentExecutor Basic Verification', () {
    test('handles Help, Cancel, StopListening correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final executor = IntentExecutor(container.read(dummyRefProvider));

      final rHelp = await executor.execute(const Help());
      expect(rHelp, isA<ExecutionSuccess>());
      expect(rHelp.spokenReply, contains('You can say play, pause'));

      final rCancel = await executor.execute(const Cancel());
      expect(rCancel, isA<ExecutionSuccess>());
      expect(rCancel.spokenReply, equals('Cancelled.'));

      final rStop = await executor.execute(const StopListening());
      expect(rStop, isA<ExecutionSuccess>());
      expect(rStop.spokenReply, equals('Stopped listening.'));
    });

    test('handles VolumeSet and Seek commands', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final executor = IntentExecutor(container.read(dummyRefProvider));

      final rVol = await executor.execute(const VolumeSet(45));
      expect(rVol, isA<ExecutionSuccess>());
      expect(rVol.spokenReply, equals('Volume 45 percent.'));

      final rSeekBy = await executor.execute(const SeekBy(30));
      expect(rSeekBy, isA<ExecutionSuccess>());
      expect(rSeekBy.spokenReply, equals('Forward 30 seconds.'));

      final rSeekBack = await executor.execute(const SeekBy(-15));
      expect(rSeekBack, isA<ExecutionSuccess>());
      expect(rSeekBack.spokenReply, equals('Back 15 seconds.'));

      final rSeekTo = await executor.execute(const SeekTo(90));
      expect(rSeekTo, isA<ExecutionSuccess>());
      expect(rSeekTo.spokenReply, equals('Seeked to 1:30.'));
    });

    test('handles Repeat and Shuffle commands', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final executor = IntentExecutor(container.read(dummyRefProvider));

      final rShuf = await executor.execute(const Shuffle(true));
      expect(rShuf, isA<ExecutionSuccess>());
      expect(rShuf.spokenReply, equals('Shuffle on.'));

      final rRep = await executor.execute(const Repeat(q.RepeatMode.one));
      expect(rRep, isA<ExecutionSuccess>());
      expect(rRep.spokenReply, equals('Repeat current song.'));
    });

    test('handles SleepTimer intent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final executor = IntentExecutor(container.read(dummyRefProvider));

      final rSleep = await executor.execute(const SleepTimer(15));
      expect(rSleep, isA<ExecutionSuccess>());
      expect(rSleep.spokenReply, equals('Stop timer set for 15 minutes.'));

      final timerState = container.read(sleepTimerProvider);
      expect(timerState.isActive, isTrue);

      final rCancel = await executor.execute(const CancelSleepTimer());
      expect(rCancel, isA<ExecutionSuccess>());
      expect(rCancel.spokenReply, equals('Stop timer cancelled.'));
      expect(container.read(sleepTimerProvider).isActive, isFalse);
    });
  });
}

final dummyRefProvider = Provider<Ref>((ref) => ref);
