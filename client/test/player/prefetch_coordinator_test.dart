import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/api_client.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/api/music_api.dart';
import 'package:melodia/core/connectivity/connectivity_controller.dart';
import 'package:melodia/downloads/offline_mode.dart';
import 'package:melodia/player/prefetch_coordinator.dart';
import 'package:melodia/player/ticket_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMusicApiForPrefetch extends MusicApi {
  FakeMusicApiForPrefetch() : super(ApiClient());

  int prefetchCalls = 0;
  List<String> lastPrefetchedIds = [];
  Map<String, String> responseStatuses = {};

  @override
  Future<Map<String, String>> prefetchAudio(
    List<String> videoIds, {
    bool head = true,
  }) async {
    prefetchCalls++;
    lastPrefetchedIds = videoIds;
    return responseStatuses.isNotEmpty
        ? responseStatuses
        : {for (final id in videoIds) id: 'queued'};
  }

  @override
  Future<Map<String, AudioTicket>> getAudioTicketsBatch(
    List<String> videoIds, {
    String purpose = 'stream',
  }) async {
    return {
      for (final id in videoIds)
        id: AudioTicket(url: '/audio/$id?t=ticket_$id', expiresIn: 3600),
    };
  }

  @override
  Future<AudioTicket> getAudioTicket(String videoId, {String purpose = 'stream'}) async {
    return AudioTicket(url: '/audio/$videoId?t=ticket_$videoId', expiresIn: 3600);
  }
}

void main() {
  group('PrefetchCoordinator', () {
    late FakeMusicApiForPrefetch fakeApi;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeApi = FakeMusicApiForPrefetch();
      container = ProviderContainer(overrides: [
        musicApiProvider.overrideWithValue(fakeApi),
      ]);
    });

    tearDown(() {
      container.dispose();
    });

    test('debounces search results and takes top 5 only', () async {
      final coordinator = container.read(prefetchCoordinatorProvider);

      coordinator.onSearchResults([
        's1', 's2', 's3', 's4', 's5', 's6', 's7',
      ]);

      // Before 250ms debounce: no prefetch
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fakeApi.prefetchCalls, equals(0));

      // After 250ms debounce: should prefetch top 5
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(fakeApi.prefetchCalls, equals(1));
      expect(fakeApi.lastPrefetchedIds, equals(['s1', 's2', 's3', 's4', 's5']));
    });

    test('row interaction (tap-down or hover) prefetches immediately with priority', () async {
      final coordinator = container.read(prefetchCoordinatorProvider);

      coordinator.onRowInteraction('tap_vid_1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fakeApi.prefetchCalls, equals(1));
      expect(fakeApi.lastPrefetchedIds, equals(['tap_vid_1']));
    });

    test('does not prefetch when offline mode is enabled', () async {
      container.read(offlineModeProvider.notifier).setManualOffline(true);
      final coordinator = container.read(prefetchCoordinatorProvider);

      coordinator.onSearchResults(['s1', 's2']);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(fakeApi.prefetchCalls, equals(0));
    });

    test('does not prefetch when smart prefetch setting is Off', () async {
      container.read(smartPrefetchModeProvider.notifier).setMode(SmartPrefetchMode.off);
      final coordinator = container.read(prefetchCoordinatorProvider);

      coordinator.onSearchResults(['s1', 's2']);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(fakeApi.prefetchCalls, equals(0));
    });

    test('backs off when server signals skipped or rate_limited', () async {
      fakeApi.responseStatuses = {'s1': 'skipped'};
      final coordinator = container.read(prefetchCoordinatorProvider);

      coordinator.onRowInteraction('s1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(fakeApi.prefetchCalls, equals(1));

      final stats = container.read(prefetchStatsProvider);
      expect(stats.skipped, equals(1));

      // Next prefetch should be blocked by 60s backoff
      coordinator.onRowInteraction('s2');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(fakeApi.prefetchCalls, equals(1)); // Still 1, s2 was blocked
    });
  });
}
