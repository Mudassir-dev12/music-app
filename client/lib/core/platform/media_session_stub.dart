/// No-op stub for platforms that don't support MediaSession
/// (Android, iOS, Windows, etc.). The audio_service package handles
/// lock-screen / notification metadata on those platforms natively.
abstract final class MediaSessionService {
  static void updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? artworkUrl,
  }) {
    // no-op on non-web platforms
  }

  static void updatePlaybackState({required bool playing}) {
    // no-op on non-web platforms
  }
}
