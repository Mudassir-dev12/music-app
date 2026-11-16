import 'models.dart';

enum MediaItemType {
  song,
  album,
  artist,
  playlist;

  static MediaItemType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'song':
        return MediaItemType.song;
      case 'album':
        return MediaItemType.album;
      case 'artist':
        return MediaItemType.artist;
      case 'playlist':
        return MediaItemType.playlist;
      default:
        return MediaItemType.song;
    }
  }

  String toTypeString() {
    switch (this) {
      case MediaItemType.song:
        return 'song';
      case MediaItemType.album:
        return 'album';
      case MediaItemType.artist:
        return 'artist';
      case MediaItemType.playlist:
        return 'playlist';
    }
  }
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.thumbnail,
    this.isExplicit = false,
    this.durationSeconds,
    this.browseId,
    this.playlistId,
    this.videoId,
  });

  final String id;
  final MediaItemType type;
  final String title;
  final String? subtitle;
  final String? thumbnail;
  final bool isExplicit;
  final int? durationSeconds;
  final String? browseId;
  final String? playlistId;
  final String? videoId;

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: (json['id'] as String?) ?? '',
        type: MediaItemType.fromString(json['type'] as String?),
        title: (json['title'] as String?) ?? '',
        subtitle: json['subtitle'] as String?,
        thumbnail: json['thumbnail'] as String?,
        isExplicit: json['is_explicit'] as bool? ?? false,
        durationSeconds: json['duration_seconds'] as int?,
        browseId: json['browse_id'] as String?,
        playlistId: json['playlist_id'] as String?,
        videoId: json['video_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toTypeString(),
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (thumbnail != null) 'thumbnail': thumbnail,
        'is_explicit': isExplicit,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (browseId != null) 'browse_id': browseId,
        if (playlistId != null) 'playlist_id': playlistId,
        if (videoId != null) 'video_id': videoId,
      };

  Track toTrack() {
    return Track(
      videoId: videoId ?? id,
      title: title,
      artists: [Artist(name: subtitle ?? 'Unknown Artist')],
      artist: subtitle ?? 'Unknown Artist',
      durationSeconds: durationSeconds,
      thumbnail: thumbnail,
      isExplicit: isExplicit,
    );
  }
}

class Shelf {
  const Shelf({
    required this.title,
    this.subtitle,
    required this.items,
    this.seeAllParams,
  });

  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final String? seeAllParams;

  factory Shelf.fromJson(Map<String, dynamic> json) => Shelf(
        title: (json['title'] as String?) ?? '',
        subtitle: json['subtitle'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        seeAllParams: json['see_all_params'] as String?,
      );
}

class SearchGrouped {
  const SearchGrouped({
    required this.query,
    this.topResult,
    required this.sections,
  });

  final String query;
  final MediaItem? topResult;
  final List<Shelf> sections;

  factory SearchGrouped.fromJson(Map<String, dynamic> json) => SearchGrouped(
        query: (json['query'] as String?) ?? '',
        topResult: json['top_result'] != null
            ? MediaItem.fromJson(json['top_result'] as Map<String, dynamic>)
            : null,
        sections: (json['sections'] as List<dynamic>?)
                ?.map((e) => Shelf.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class SearchFilter {
  const SearchFilter({
    required this.query,
    required this.filter,
    required this.results,
  });

  final String query;
  final String filter;
  final List<MediaItem> results;

  factory SearchFilter.fromJson(Map<String, dynamic> json) => SearchFilter(
        query: (json['query'] as String?) ?? '',
        filter: (json['filter'] as String?) ?? '',
        results: (json['results'] as List<dynamic>?)
                ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class AlbumDetail {
  const AlbumDetail({
    required this.id,
    required this.title,
    required this.artists,
    required this.artist,
    this.year,
    required this.trackCount,
    required this.durationSeconds,
    this.thumbnail,
    this.description,
    required this.tracks,
  });

  final String id;
  final String title;
  final List<Artist> artists;
  final String artist;
  final int? year;
  final int trackCount;
  final int durationSeconds;
  final String? thumbnail;
  final String? description;
  final List<Track> tracks;

  factory AlbumDetail.fromJson(Map<String, dynamic> json) => AlbumDetail(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        artists: (json['artists'] as List<dynamic>?)
                ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        artist: (json['artist'] as String?) ?? '',
        year: json['year'] as int?,
        trackCount: (json['track_count'] as int?) ?? 0,
        durationSeconds: (json['duration_seconds'] as int?) ?? 0,
        thumbnail: json['thumbnail'] as String?,
        description: json['description'] as String?,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class ArtistDetail {
  const ArtistDetail({
    required this.id,
    required this.name,
    this.thumbnail,
    this.description,
    this.subscribers,
    required this.topSongs,
    required this.albums,
    required this.singles,
    required this.related,
  });

  final String id;
  final String name;
  final String? thumbnail;
  final String? description;
  final String? subscribers;
  final List<Track> topSongs;
  final List<MediaItem> albums;
  final List<MediaItem> singles;
  final List<MediaItem> related;

  factory ArtistDetail.fromJson(Map<String, dynamic> json) => ArtistDetail(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        thumbnail: json['thumbnail'] as String?,
        description: json['description'] as String?,
        subscribers: json['subscribers'] as String?,
        topSongs: (json['top_songs'] as List<dynamic>?)
                ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        albums: (json['albums'] as List<dynamic>?)
                ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        singles: (json['singles'] as List<dynamic>?)
                ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        related: (json['related'] as List<dynamic>?)
                ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class YtPlaylistDetail {
  const YtPlaylistDetail({
    required this.id,
    required this.title,
    this.author,
    required this.trackCount,
    required this.durationSeconds,
    this.thumbnail,
    this.description,
    required this.tracks,
  });

  final String id;
  final String title;
  final String? author;
  final int trackCount;
  final int durationSeconds;
  final String? thumbnail;
  final String? description;
  final List<Track> tracks;

  factory YtPlaylistDetail.fromJson(Map<String, dynamic> json) =>
      YtPlaylistDetail(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        author: json['author'] as String?,
        trackCount: (json['track_count'] as int?) ?? 0,
        durationSeconds: (json['duration_seconds'] as int?) ?? 0,
        thumbnail: json['thumbnail'] as String?,
        description: json['description'] as String?,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class LyricLine {
  const LyricLine({required this.startMs, required this.text});

  final int startMs;
  final String text;

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        startMs: (json['start_ms'] as int?) ?? 0,
        text: (json['text'] as String?) ?? '',
      );
}

class Lyrics {
  const Lyrics({
    required this.videoId,
    this.plain,
    required this.synced,
    this.source,
  });

  final String videoId;
  final String? plain;
  final List<LyricLine> synced;
  final String? source;

  bool get isSynced => synced.isNotEmpty;

  factory Lyrics.fromJson(Map<String, dynamic> json) => Lyrics(
        videoId: (json['video_id'] as String?) ?? '',
        plain: json['plain'] as String?,
        synced: (json['synced'] as List<dynamic>?)
                ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        source: json['source'] as String?,
      );
}

class MoodCategory {
  const MoodCategory({required this.title, required this.params});

  final String title;
  final String params;

  factory MoodCategory.fromJson(Map<String, dynamic> json) => MoodCategory(
        title: (json['title'] as String?) ?? '',
        params: (json['params'] as String?) ?? '',
      );
}

class MoodSection {
  const MoodSection({required this.title, required this.categories});

  final String title;
  final List<MoodCategory> categories;

  factory MoodSection.fromJson(Map<String, dynamic> json) => MoodSection(
        title: (json['title'] as String?) ?? '',
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => MoodCategory.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class MoodsResponse {
  const MoodsResponse({required this.sections});

  final List<MoodSection> sections;

  factory MoodsResponse.fromJson(Map<String, dynamic> json) => MoodsResponse(
        sections: (json['sections'] as List<dynamic>?)
                ?.map((e) => MoodSection.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
