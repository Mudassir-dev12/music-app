import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/discovery_api.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/player/autoplay_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockDiscoveryApi extends Mock implements DiscoveryApi {}

void main() {
  group('Autoplay Controller - getAutoplayCandidates', () {
    late MockDiscoveryApi mockDiscoveryApi;

    setUp(() {
      mockDiscoveryApi = MockDiscoveryApi();
    });

    final seedTrack = const Track(
      videoId: 'seed_vid',
      title: 'Seed Track',
      artists: [Artist(name: 'Artist A')],
      artist: 'Artist A',
      isExplicit: false,
    );

    final trackInQueue = const Track(
      videoId: 'queued_vid',
      title: 'Queued Track',
      artists: [Artist(name: 'Artist B')],
      artist: 'Artist B',
      isExplicit: false,
    );

    final newRadioTrack1 = const Track(
      videoId: 'new_radio_1',
      title: 'New Track 1',
      artists: [Artist(name: 'Artist C')],
      artist: 'Artist C',
      isExplicit: false,
    );

    final newRadioTrack2 = const Track(
      videoId: 'new_radio_2',
      title: 'New Track 2',
      artists: [Artist(name: 'Artist D')],
      artist: 'Artist D',
      isExplicit: false,
    );

    test('filters out seed track and existing queue tracks', () async {
      when(() => mockDiscoveryApi.getWatchRadio('seed_vid')).thenAnswer(
        (_) async => [seedTrack, trackInQueue, newRadioTrack1, newRadioTrack2],
      );

      final candidates = await getAutoplayCandidates(
        discoveryApi: mockDiscoveryApi,
        seedTrack: seedTrack,
        existingQueue: [trackInQueue],
      );

      expect(candidates.length, equals(2));
      expect(candidates[0].videoId, equals('new_radio_1'));
      expect(candidates[1].videoId, equals('new_radio_2'));
    });

    test('returns empty list if upstream watch radio throws', () async {
      when(() => mockDiscoveryApi.getWatchRadio('seed_vid')).thenThrow(
        Exception('Network failure'),
      );

      final candidates = await getAutoplayCandidates(
        discoveryApi: mockDiscoveryApi,
        seedTrack: seedTrack,
        existingQueue: [trackInQueue],
      );

      expect(candidates, isEmpty);
    });
  });
}
