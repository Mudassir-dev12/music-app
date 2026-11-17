import 'dart:convert';
import '../api/models.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

enum FailReason {
  network,
  quota,
  tooLarge,
  unavailable,
  storageFull,
  corrupt,
  unsupported,
}

class DownloadItem {
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final FailReason? failReason;
  final String? errorMessage;
  final DateTime? retryAfter;
  final Set<String> collections;

  const DownloadItem({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    this.durationSeconds,
    this.thumbnailUrl,
    this.status = DownloadStatus.queued,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.failReason,
    this.errorMessage,
    this.retryAfter,
    this.collections = const {},
  });

  double get progress {
    if (totalBytes > 0) {
      return (bytesDownloaded / totalBytes).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String get statusText {
    switch (status) {
      case DownloadStatus.queued:
        return 'Waiting';
      case DownloadStatus.downloading:
        final pct = (progress * 100).toInt();
        return 'Downloading $pct%';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Downloaded';
      case DownloadStatus.failed:
        switch (failReason) {
          case FailReason.quota:
            if (retryAfter != null) {
              final h = retryAfter!.hour.toString().padLeft(2, '0');
              final m = retryAfter!.minute.toString().padLeft(2, '0');
              return "Daily limit reached. Resets at $h:$m";
            }
            return "Daily download limit reached";
          case FailReason.storageFull:
            return 'Storage full';
          case FailReason.tooLarge:
            return 'File too large';
          case FailReason.unavailable:
            return 'Song unavailable';
          case FailReason.corrupt:
            return 'Integrity check failed';
          case FailReason.unsupported:
            return 'Not supported on web';
          case FailReason.network:
          default:
            return 'Network error';
        }
      case DownloadStatus.canceled:
        return 'Canceled';
    }
  }

  DownloadItem copyWith({
    String? videoId,
    String? title,
    String? artist,
    String? album,
    int? durationSeconds,
    String? thumbnailUrl,
    DownloadStatus? status,
    int? bytesDownloaded,
    int? totalBytes,
    FailReason? failReason,
    String? errorMessage,
    DateTime? retryAfter,
    Set<String>? collections,
  }) {
    return DownloadItem(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      failReason: failReason ?? this.failReason,
      errorMessage: errorMessage ?? this.errorMessage,
      retryAfter: retryAfter ?? this.retryAfter,
      collections: collections ?? this.collections,
    );
  }
}

class ManifestTrack {
  final String videoId;
  final String title;
  final String artist;
  final List<String> artists;
  final String? album;
  final String? albumId;
  final int durationSeconds;
  final String? thumbnailFile;
  final int byteSize;
  final String extension;
  final DateTime downloadedAt;
  final Set<String> collections;

  const ManifestTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    this.artists = const [],
    this.album,
    this.albumId,
    required this.durationSeconds,
    this.thumbnailFile,
    required this.byteSize,
    this.extension = 'm4a',
    required this.downloadedAt,
    this.collections = const {},
  });

  Track toTrack() {
    final artistList = artists.isNotEmpty
        ? artists.map((a) => Artist(name: a)).toList()
        : [Artist(name: artist)];
    return Track(
      videoId: videoId,
      title: title,
      artist: artist,
      artists: artistList,
      album: album,
      albumId: albumId,
      durationSeconds: durationSeconds,
      thumbnail: thumbnailFile,
      isExplicit: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'artist': artist,
      'artists': artists,
      'album': album,
      'albumId': albumId,
      'durationSeconds': durationSeconds,
      'thumbnailFile': thumbnailFile,
      'byteSize': byteSize,
      'extension': extension,
      'downloadedAt': downloadedAt.toIso8601String(),
      'collections': collections.toList(),
    };
  }

  factory ManifestTrack.fromJson(Map<String, dynamic> json) {
    return ManifestTrack(
      videoId: json['videoId'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      artists: (json['artists'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      album: json['album'] as String?,
      albumId: json['albumId'] as String?,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      thumbnailFile: json['thumbnailFile'] as String?,
      byteSize: json['byteSize'] as int? ?? 0,
      extension: json['extension'] as String? ?? 'm4a',
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      collections: (json['collections'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
    );
  }

  ManifestTrack copyWith({
    String? videoId,
    String? title,
    String? artist,
    List<String>? artists,
    String? album,
    String? albumId,
    int? durationSeconds,
    String? thumbnailFile,
    int? byteSize,
    String? extension,
    DateTime? downloadedAt,
    Set<String>? collections,
  }) {
    return ManifestTrack(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailFile: thumbnailFile ?? this.thumbnailFile,
      byteSize: byteSize ?? this.byteSize,
      extension: extension ?? this.extension,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      collections: collections ?? this.collections,
    );
  }
}

class DownloadManifest {
  static const int currentSchema = 1;

  final int schema;
  final Map<String, ManifestTrack> tracks;

  const DownloadManifest({
    this.schema = currentSchema,
    this.tracks = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'schema': schema,
      'tracks': tracks.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory DownloadManifest.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as int? ?? 1;
    final rawTracks = json['tracks'] as Map<String, dynamic>? ?? {};
    final tracks = <String, ManifestTrack>{};
    for (final entry in rawTracks.entries) {
      try {
        if (entry.value is Map<String, dynamic>) {
          tracks[entry.key] = ManifestTrack.fromJson(entry.value as Map<String, dynamic>);
        }
      } catch (_) {
        // Skip corrupt single entry rather than losing all
      }
    }
    return DownloadManifest(schema: schema, tracks: tracks);
  }

  String encode() => jsonEncode(toJson());

  static DownloadManifest decode(String content) {
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return DownloadManifest.fromJson(decoded);
  }
}

class CollectionSync {
  final String collectionKey; // 'liked', 'playlist:<id>', 'album:<id>'
  final String title;
  final bool keepOffline;
  final int totalTracks;
  final int downloadedTracks;

  const CollectionSync({
    required this.collectionKey,
    required this.title,
    this.keepOffline = false,
    this.totalTracks = 0,
    this.downloadedTracks = 0,
  });

  double get progress => totalTracks > 0 ? (downloadedTracks / totalTracks).clamp(0.0, 1.0) : 0.0;
  bool get isComplete => totalTracks > 0 && downloadedTracks >= totalTracks;

  CollectionSync copyWith({
    String? collectionKey,
    String? title,
    bool? keepOffline,
    int? totalTracks,
    int? downloadedTracks,
  }) {
    return CollectionSync(
      collectionKey: collectionKey ?? this.collectionKey,
      title: title ?? this.title,
      keepOffline: keepOffline ?? this.keepOffline,
      totalTracks: totalTracks ?? this.totalTracks,
      downloadedTracks: downloadedTracks ?? this.downloadedTracks,
    );
  }
}
