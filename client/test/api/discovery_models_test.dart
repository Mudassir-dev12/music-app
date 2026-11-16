import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/discovery_models.dart';

void main() {
  group('Discovery Models Parsing', () {
    test('MediaItem parsing and toTrack helper', () {
      final json = {
        'id': 'med_123',
        'type': 'song',
        'title': 'Test Song',
        'subtitle': 'Test Artist',
        'thumbnail': 'https://example.com/thumb.jpg',
        'is_explicit': true,
        'duration_seconds': 210,
        'video_id': 'vid_123',
      };

      final item = MediaItem.fromJson(json);
      expect(item.id, equals('med_123'));
      expect(item.type, equals(MediaItemType.song));
      expect(item.title, equals('Test Song'));
      expect(item.subtitle, equals('Test Artist'));
      expect(item.isExplicit, isTrue);
      expect(item.durationSeconds, equals(210));
      expect(item.videoId, equals('vid_123'));

      final track = item.toTrack();
      expect(track.videoId, equals('vid_123'));
      expect(track.title, equals('Test Song'));
      expect(track.artist, equals('Test Artist'));
      expect(track.isExplicit, isTrue);
      expect(track.durationSeconds, equals(210));
    });

    test('Shelf parsing with items', () {
      final json = {
        'title': 'Top Hits',
        'subtitle': 'Most played',
        'items': [
          {'id': 'alb_1', 'type': 'album', 'title': 'Hit Album', 'subtitle': 'Hit Artist'},
        ],
        'see_all_params': 'param123',
      };

      final shelf = Shelf.fromJson(json);
      expect(shelf.title, equals('Top Hits'));
      expect(shelf.subtitle, equals('Most played'));
      expect(shelf.items.length, equals(1));
      expect(shelf.items.first.type, equals(MediaItemType.album));
      expect(shelf.seeAllParams, equals('param123'));
    });

    test('SearchGrouped and SearchFilter parsing', () {
      final groupedJson = {
        'query': 'coldplay',
        'top_result': {'id': 'art_1', 'type': 'artist', 'title': 'Coldplay'},
        'sections': [
          {'title': 'Songs', 'items': <Map<String, dynamic>>[]},
        ],
      };

      final grouped = SearchGrouped.fromJson(groupedJson);
      expect(grouped.query, equals('coldplay'));
      expect(grouped.topResult, isNotNull);
      expect(grouped.topResult!.type, equals(MediaItemType.artist));
      expect(grouped.sections.length, equals(1));

      final filterJson = {
        'query': 'coldplay',
        'filter': 'albums',
        'results': [
          {'id': 'alb_1', 'type': 'album', 'title': 'Parachutes'},
        ],
      };

      final filterRes = SearchFilter.fromJson(filterJson);
      expect(filterRes.query, equals('coldplay'));
      expect(filterRes.filter, equals('albums'));
      expect(filterRes.results.length, equals(1));
    });

    test('AlbumDetail parsing', () {
      final json = {
        'id': 'alb_123',
        'title': 'Great Album',
        'artists': [{'name': 'Lead Singer'}],
        'artist': 'Lead Singer',
        'year': 2021,
        'track_count': 10,
        'duration_seconds': 2400,
        'tracks': [
          {
            'video_id': 'v1',
            'title': 'Track One',
            'artist': 'Lead Singer',
            'artists': [{'name': 'Lead Singer'}],
            'is_explicit': false,
            'track_number': 1,
          }
        ],
      };

      final album = AlbumDetail.fromJson(json);
      expect(album.id, equals('alb_123'));
      expect(album.title, equals('Great Album'));
      expect(album.year, equals(2021));
      expect(album.tracks.length, equals(1));
      expect(album.tracks.first.trackNumber, equals(1));
    });

    test('Lyrics parsing and isSynced flag', () {
      final syncedJson = {
        'video_id': 'vid_synced',
        'plain': null,
        'synced': [
          {'start_ms': 1000, 'text': 'Hello world'},
        ],
        'source': 'YouTube',
      };

      final lyrics = Lyrics.fromJson(syncedJson);
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.synced.length, equals(1));
      expect(lyrics.synced.first.text, equals('Hello world'));
      expect(lyrics.source, equals('YouTube'));

      final plainJson = {
        'video_id': 'vid_plain',
        'plain': 'Just some lyrics',
        'synced': <Map<String, dynamic>>[],
      };

      final plainLyrics = Lyrics.fromJson(plainJson);
      expect(plainLyrics.isSynced, isFalse);
      expect(plainLyrics.plain, equals('Just some lyrics'));
    });
  });
}
