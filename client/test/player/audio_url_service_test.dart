import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/api/music_api.dart';
import 'package:melodia/player/audio_url_service.dart';
import 'package:melodia/player/ticket_cache.dart';
import 'package:mocktail/mocktail.dart';

class MockMusicApi extends Mock implements MusicApi {}

void main() {
  late MockMusicApi mockMusicApi;
  late TicketCache ticketCache;
  late AudioUrlService service;

  setUp(() {
    mockMusicApi = MockMusicApi();
    ticketCache = TicketCache(mockMusicApi);
    service = AudioUrlService(ticketCache);
  });

  test('urlFor fetches ticket from backend and returns absolute URL', () async {
    when(() => mockMusicApi.getAudioTicket('vid_1234567')).thenAnswer(
      (_) async => const AudioTicket(
        url: '/audio/vid_1234567?t=mock_jwt',
        expiresIn: 7200,
      ),
    );

    final url = await service.urlFor('vid_1234567');
    expect(url, contains('/audio/vid_1234567?t=mock_jwt'));
    verify(() => mockMusicApi.getAudioTicket('vid_1234567')).called(1);
  });

  test('urlFor uses cached ticket if valid and not expiring soon', () async {
    when(() => mockMusicApi.getAudioTicket('vid_1234567')).thenAnswer(
      (_) async => const AudioTicket(
        url: '/audio/vid_1234567?t=mock_jwt',
        expiresIn: 7200, // 2 hours
      ),
    );

    final url1 = await service.urlFor('vid_1234567');
    final url2 = await service.urlFor('vid_1234567');

    expect(url1, equals(url2));
    verify(() => mockMusicApi.getAudioTicket('vid_1234567')).called(1); // Only 1 network call
  });

  test('invalidate clears cached ticket and forces fresh fetch', () async {
    when(() => mockMusicApi.getAudioTicket('vid_1234567')).thenAnswer(
      (_) async => const AudioTicket(
        url: '/audio/vid_1234567?t=mock_jwt',
        expiresIn: 7200,
      ),
    );

    await service.urlFor('vid_1234567');
    service.invalidate('vid_1234567');
    await service.urlFor('vid_1234567');

    verify(() => mockMusicApi.getAudioTicket('vid_1234567')).called(2);
  });
}

