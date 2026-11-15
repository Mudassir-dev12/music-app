// Web implementation — uses package:web for navigator.mediaSession
import 'dart:js_interop';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

abstract final class MediaSessionService {
  static void updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? artworkUrl,
  }) {
    try {
      final session = web.window.navigator.mediaSession;
      final artwork = artworkUrl != null
          ? [
              web.MediaImage(
                src: artworkUrl,
                sizes: '512x512',
                type: 'image/jpeg',
              ),
            ]
          : <web.MediaImage>[];

      session.metadata = web.MediaMetadata(
        web.MediaMetadataInit(
          title: title,
          artist: artist,
          album: album,
          artwork: artwork.toJS,
        ),
      );
    } catch (_) {
      // mediaSession not supported or restricted in environment
    }
  }

  static void updatePlaybackState({required bool playing}) {
    try {
      web.window.navigator.mediaSession.playbackState =
          playing ? 'playing' : 'paused';
    } catch (_) {}
  }
}
