import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/api_client.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/api/music_api.dart';
import 'package:melodia/player/ticket_cache.dart';

class FakeMusicApiForTickets extends MusicApi {
  FakeMusicApiForTickets() : super(ApiClient());

  int batchCallsCount = 0;
  int singleCallsCount = 0;
  List<List<String>> batchVideoIds = [];

  @override
  Future<Map<String, AudioTicket>> getAudioTicketsBatch(
    List<String> videoIds, {
    String purpose = 'stream',
  }) async {
    batchCallsCount++;
    batchVideoIds.add(videoIds);
    return {
      for (final id in videoIds)
        id: AudioTicket(url: '/audio/$id?t=ticket_$id', expiresIn: 3600),
    };
  }

  @override
  Future<AudioTicket> getAudioTicket(
    String videoId, {
    String purpose = 'stream',
  }) async {
    singleCallsCount++;
    return AudioTicket(url: '/audio/$videoId?t=ticket_$videoId', expiresIn: 3600);
  }
}

void main() {
  group('TicketCache', () {
    test('coalesces multiple requests within 30ms into a single batch call', () async {
      final fakeApi = FakeMusicApiForTickets();
      final cache = TicketCache(fakeApi);

      // Request 3 tickets concurrently
      final f1 = cache.getUrl('vid_1');
      final f2 = cache.getUrl('vid_2');
      final f3 = cache.getUrl('vid_3');

      // Wait 50ms for batch timer to flush
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final r1 = await f1;
      final r2 = await f2;
      final r3 = await f3;

      expect(r1, contains('/audio/vid_1?t=ticket_vid_1'));
      expect(r2, contains('/audio/vid_2?t=ticket_vid_2'));
      expect(r3, contains('/audio/vid_3?t=ticket_vid_3'));

      expect(fakeApi.batchCallsCount, equals(1));
      expect(fakeApi.batchVideoIds.first, equals(['vid_1', 'vid_2', 'vid_3']));
    });

    test('serves cached ticket immediately without API call', () async {
      final fakeApi = FakeMusicApiForTickets();
      final cache = TicketCache(fakeApi);

      cache.put(
        'cached_vid',
        const AudioTicket(url: '/audio/cached_vid?t=cached', expiresIn: 3600),
      );

      final url = await cache.getUrl('cached_vid');
      expect(url, contains('/audio/cached_vid?t=cached'));
      expect(fakeApi.batchCallsCount, equals(0));
      expect(fakeApi.singleCallsCount, equals(0));
    });

    test('refetches ticket when expired or within 60s safety margin', () async {
      final fakeApi = FakeMusicApiForTickets();
      final cache = TicketCache(fakeApi);

      // Put ticket with only 30s remaining (within 60s safety margin -> expired)
      cache.put(
        'expired_vid',
        const AudioTicket(url: '/audio/expired_vid?t=old', expiresIn: 30),
      );

      final f = cache.getUrl('expired_vid');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final url = await f;

      expect(url, contains('/audio/expired_vid?t=ticket_expired_vid'));
      expect(fakeApi.singleCallsCount, equals(1));
    });

    test('invalidate removes cached ticket forcing re-fetch', () async {
      final fakeApi = FakeMusicApiForTickets();
      final cache = TicketCache(fakeApi);

      cache.put(
        'vid_inv',
        const AudioTicket(url: '/audio/vid_inv?t=first', expiresIn: 3600),
      );
      cache.invalidate('vid_inv');

      expect(cache.getCachedUrl('vid_inv'), isNull);
    });
  });
}
