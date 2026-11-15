import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/errors.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/api/user_api.dart';
import 'package:melodia/player/history_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOutboxUserApi implements UserApi {
  final List<String> recordedVideoIds = [];
  bool throwValidationError = false;
  bool throwRateLimitError = false;

  @override
  Future<HistoryItem> recordHistory({
    required String videoId,
    required int listenedSeconds,
    required String clientEventId,
  }) async {
    if (throwValidationError) {
      throw const ValidationError(fields: {'video_id': 'Invalid'});
    }
    if (throwRateLimitError) {
      throw const RateLimitError(retryAfterSeconds: 60);
    }
    recordedVideoIds.add(videoId);
    return HistoryItem(
      id: 1,
      track: Track(
        videoId: videoId,
        title: 'Title',
        artists: const [Artist(id: 'a1', name: 'Artist')],
        artist: 'Artist',
        durationSeconds: 120,
        isExplicit: false,
      ),
      listenedSeconds: listenedSeconds,
      playedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Track>> getRecent({int limit = 20}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HistoryOutbox & UUID generator', () {
    test('generateUuidV4 returns valid RFC-4122 v4 format', () {
      final uuid = generateUuidV4();
      expect(uuid.length, equals(36));
      expect(uuid[14], equals('4')); // Version 4
      expect(['8', '9', 'a', 'b'], contains(uuid[19])); // Variant
      final parts = uuid.split('-');
      expect(parts.length, equals(5));
      expect(parts[0].length, equals(8));
      expect(parts[1].length, equals(4));
      expect(parts[2].length, equals(4));
      expect(parts[3].length, equals(4));
      expect(parts[4].length, equals(12));
    });

    test('enqueue stores items in SharedPreferences and flush records them', () async {
      final mock = MockOutboxUserApi();
      final container = ProviderContainer(
        overrides: [
          userApiProvider.overrideWithValue(mock),
        ],
      );

      final box = container.read(historyOutboxProvider);
      await box.enqueue('testVid0001', 30);
      expect(mock.recordedVideoIds, contains('testVid0001'));
    });

    test('flush drops items on 4xx validation error to prevent poisoning', () async {
      final mock = MockOutboxUserApi()..throwValidationError = true;
      final container = ProviderContainer(
        overrides: [
          userApiProvider.overrideWithValue(mock),
        ],
      );
      final box = container.read(historyOutboxProvider);

      await box.enqueue('badVid00001', 30);

      // Verify that after 4xx error, outbox dropped the item from prefs
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('history_outbox_items');
      expect(raw, equals('[]'));
    });

    test('flush keeps items on rate limit for retry', () async {
      final mock = MockOutboxUserApi()..throwRateLimitError = true;
      final container = ProviderContainer(
        overrides: [
          userApiProvider.overrideWithValue(mock),
        ],
      );
      final box = container.read(historyOutboxProvider);

      await box.enqueue('retryVid001', 30);

      // Verify that after 429 error, outbox retains the item
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('history_outbox_items');
      expect(raw, contains('retryVid001'));
    });
  });
}
