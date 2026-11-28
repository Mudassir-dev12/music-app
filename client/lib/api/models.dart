/// Hand-written JSON models for the Melodia API.
/// No code generation (no freezed / json_serializable).
library;

/// An artist on a track.
class Artist {
  const Artist({this.id, required this.name});

  final String? id;
  final String name;

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: json['id'] as String?,
        name: (json['name'] as String?) ?? 'Unknown Artist',
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
      };
}

/// A music track returned by the API.
class Track {
  const Track({
    required this.videoId,
    required this.title,
    required this.artists,
    required this.artist,
    this.album,
    this.albumId,
    this.durationSeconds,
    this.thumbnail,
    required this.isExplicit,
    this.trackNumber,
  });

  final String videoId;
  final String title;
  final List<Artist> artists;
  final String artist;
  final String? album;
  final String? albumId;
  final int? durationSeconds;
  final String? thumbnail;
  final bool isExplicit;
  final int? trackNumber;

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        videoId: (json['video_id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        artists: (json['artists'] as List<dynamic>?)
                ?.map((a) => Artist.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
        artist: (json['artist'] as String?) ?? '',
        album: json['album'] as String?,
        albumId: json['album_id'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
        thumbnail: json['thumbnail'] as String?,
        isExplicit: json['is_explicit'] as bool? ?? false,
        trackNumber: json['track_number'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'title': title,
        'artists': artists.map((a) => a.toJson()).toList(),
        'artist': artist,
        if (album != null) 'album': album,
        if (albumId != null) 'album_id': albumId,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (thumbnail != null) 'thumbnail': thumbnail,
        'is_explicit': isExplicit,
        if (trackNumber != null) 'track_number': trackNumber,
      };
}

/// Search results page.
class SearchResponse {
  const SearchResponse({
    required this.query,
    required this.filter,
    required this.results,
  });

  final String query;
  final String filter;
  final List<Track> results;

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
        query: (json['query'] as String?) ?? '',
        filter: (json['filter'] as String?) ?? 'songs',
        results: (json['results'] as List<dynamic>?)
                ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Authenticated user profile.
class UserOut {
  const UserOut({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  factory UserOut.fromJson(Map<String, dynamic> json) => UserOut(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (displayName != null) 'display_name': displayName,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Access + refresh token pair returned by auth endpoints.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserOut user;

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        expiresIn: json['expires_in'] as int,
        user: UserOut.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// A short-lived URL ticket for streaming audio.
class AudioTicket {
  const AudioTicket({
    required this.url,
    required this.expiresIn,
    this.purpose = 'stream',
    this.remainingDownloadMb,
    this.maxTrackMb,
  });

  final String url;
  final int expiresIn;
  final String purpose;
  final int? remainingDownloadMb;
  final int? maxTrackMb;

  factory AudioTicket.fromJson(Map<String, dynamic> json) => AudioTicket(
        url: json['url'] as String,
        expiresIn: json['expires_in'] as int,
        purpose: (json['purpose'] as String?) ?? 'stream',
        remainingDownloadMb: json['remaining_download_mb'] as int?,
        maxTrackMb: json['max_track_mb'] as int?,
      );
}

/// Download limits and quota information.
class DownloadLimits {
  const DownloadLimits({
    required this.dailyDownloadMbLimit,
    required this.dailyDownloadMbRemaining,
    required this.remainingDownloadMb,
    required this.maxDownloadTrackMb,
    required this.maxConcurrentDownloadsPerUser,
    required this.maxConcurrentDownloadsGlobal,
  });

  final int dailyDownloadMbLimit;
  final int dailyDownloadMbRemaining;
  final int remainingDownloadMb;
  final int maxDownloadTrackMb;
  final int maxConcurrentDownloadsPerUser;
  final int maxConcurrentDownloadsGlobal;

  factory DownloadLimits.fromJson(Map<String, dynamic> json) => DownloadLimits(
        dailyDownloadMbLimit: json['daily_download_mb_limit'] as int? ?? 1000,
        dailyDownloadMbRemaining: json['daily_download_mb_remaining'] as int? ?? 1000,
        remainingDownloadMb: json['remaining_download_mb'] as int? ?? 1000,
        maxDownloadTrackMb: json['max_download_track_mb'] as int? ?? 80,
        maxConcurrentDownloadsPerUser: json['max_concurrent_downloads_per_user'] as int? ?? 2,
        maxConcurrentDownloadsGlobal: json['max_concurrent_downloads_global'] as int? ?? 4,
      );
}

// ---------------------------------------------------------------------------
// Phase 3 User Data Models
// ---------------------------------------------------------------------------

/// Generic cursor-paginated page.
class Page<T> {
  const Page({
    required this.items,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// A play history record.
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.playedAt,
    required this.listenedSeconds,
    required this.track,
  });

  final int id;
  final DateTime playedAt;
  final int listenedSeconds;
  final Track track;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as int,
        playedAt: DateTime.parse(json['played_at'] as String),
        listenedSeconds: json['listened_seconds'] as int,
        track: Track.fromJson(json['track'] as Map<String, dynamic>),
      );
}

/// A liked track item.
class LikedItem {
  const LikedItem({
    required this.likedAt,
    required this.track,
  });

  final DateTime likedAt;
  final Track track;

  factory LikedItem.fromJson(Map<String, dynamic> json) => LikedItem(
        likedAt: DateTime.parse(json['liked_at'] as String),
        track: Track.fromJson(json['track'] as Map<String, dynamic>),
      );
}

/// Playlist summary item.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.trackCount,
    required this.durationSeconds,
    required this.coverThumbnails,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int trackCount;
  final int durationSeconds;
  final List<String> coverThumbnails;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist copyWith({
    String? name,
    String? description,
    int? trackCount,
    int? durationSeconds,
    List<String>? coverThumbnails,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackCount: trackCount ?? this.trackCount,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      coverThumbnails: coverThumbnails ?? this.coverThumbnails,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'track_count': trackCount,
        'duration_seconds': durationSeconds,
        'cover_thumbnails': coverThumbnails,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        description: json['description'] as String?,
        trackCount: (json['track_count'] as int?) ?? 0,
        durationSeconds: (json['duration_seconds'] as int?) ?? 0,
        coverThumbnails: (json['cover_thumbnails'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// An entry in a playlist.
class PlaylistTrackItem {
  const PlaylistTrackItem({
    required this.position,
    required this.addedAt,
    required this.track,
  });

  final int position;
  final DateTime addedAt;
  final Track track;

  Map<String, dynamic> toJson() => {
        'position': position,
        'added_at': addedAt.toIso8601String(),
        'track': track.toJson(),
      };

  factory PlaylistTrackItem.fromJson(Map<String, dynamic> json) =>
      PlaylistTrackItem(
        position: json['position'] as int,
        addedAt: DateTime.parse(json['added_at'] as String),
        track: Track.fromJson(json['track'] as Map<String, dynamic>),
      );
}

/// Detailed playlist info including paginated tracks.
class PlaylistDetail {
  const PlaylistDetail({
    required this.id,
    required this.name,
    this.description,
    required this.trackCount,
    required this.durationSeconds,
    required this.coverThumbnails,
    required this.createdAt,
    required this.updatedAt,
    required this.tracks,
  });

  final String id;
  final String name;
  final String? description;
  final int trackCount;
  final int durationSeconds;
  final List<String> coverThumbnails;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Page<PlaylistTrackItem> tracks;

  PlaylistDetail copyWith({
    String? name,
    String? description,
    int? trackCount,
    int? durationSeconds,
    List<String>? coverThumbnails,
    DateTime? updatedAt,
    Page<PlaylistTrackItem>? tracks,
  }) {
    return PlaylistDetail(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackCount: trackCount ?? this.trackCount,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      coverThumbnails: coverThumbnails ?? this.coverThumbnails,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tracks: tracks ?? this.tracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'track_count': trackCount,
        'duration_seconds': durationSeconds,
        'cover_thumbnails': coverThumbnails,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'tracks': {
          'items': tracks.items.map((e) => e.toJson()).toList(),
          'next_cursor': tracks.nextCursor,
        },
      };

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final tracksJson = json['tracks'] as Map<String, dynamic>? ?? {};
    final trackItems = (tracksJson['items'] as List<dynamic>?)
            ?.map((e) => PlaylistTrackItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final nextCursor = tracksJson['next_cursor'] as String?;

    return PlaylistDetail(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      trackCount: (json['track_count'] as int?) ?? 0,
      durationSeconds: (json['duration_seconds'] as int?) ?? 0,
      coverThumbnails: (json['cover_thumbnails'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tracks: Page(items: trackItems, nextCursor: nextCursor),
    );
  }
}

/// Result returned from adding tracks to a playlist.
class PlaylistAddResult {
  const PlaylistAddResult({required this.added, required this.skipped});

  final int added;
  final List<String> skipped;

  factory PlaylistAddResult.fromJson(Map<String, dynamic> json) =>
      PlaylistAddResult(
        added: json['added'] as int,
        skipped: (json['skipped'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}
