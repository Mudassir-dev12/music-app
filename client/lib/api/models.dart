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
        name: json['name'] as String,
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

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        videoId: json['video_id'] as String,
        title: json['title'] as String,
        artists: (json['artists'] as List<dynamic>)
            .map((a) => Artist.fromJson(a as Map<String, dynamic>))
            .toList(),
        artist: json['artist'] as String,
        album: json['album'] as String?,
        albumId: json['album_id'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
        thumbnail: json['thumbnail'] as String?,
        isExplicit: json['is_explicit'] as bool? ?? false,
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
        query: json['query'] as String,
        filter: json['filter'] as String,
        results: (json['results'] as List<dynamic>)
            .map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList(),
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
  const AudioTicket({required this.url, required this.expiresIn});

  final String url;
  final int expiresIn;

  factory AudioTicket.fromJson(Map<String, dynamic> json) => AudioTicket(
        url: json['url'] as String,
        expiresIn: json['expires_in'] as int,
      );
}
