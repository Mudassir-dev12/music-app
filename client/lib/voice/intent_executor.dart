import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/discovery_api.dart';
import '../api/discovery_models.dart';
import '../api/models.dart';
import '../api/user_api.dart';
import '../core/connectivity/connectivity_controller.dart';
import '../data/user_data_providers.dart';
import '../downloads/download_models.dart';
import '../downloads/download_repository.dart';
import '../downloads/offline_mode.dart';
import '../player/autoplay_controller.dart';
import '../player/player_controller.dart';
import '../player/queue.dart' as q;
import '../player/sleep_timer.dart';
import 'entity_matcher.dart';
import 'voice_intent.dart';

sealed class ExecutionResult {
  const ExecutionResult(this.spokenReply, {this.displayText});
  final String spokenReply;
  final String? displayText;
}

final class ExecutionSuccess extends ExecutionResult {
  const ExecutionSuccess(super.spokenReply, {super.displayText});
}

final class ExecutionDisambiguationRequired extends ExecutionResult {
  const ExecutionDisambiguationRequired({
    required String spokenReply,
    required this.candidates,
  }) : super(spokenReply);
  final List<Track> candidates;
}

final class ExecutionFailure extends ExecutionResult {
  const ExecutionFailure(super.spokenReply, {super.displayText});
}

class IntentExecutor {
  const IntentExecutor(this.ref);

  final Ref ref;

  PlayerController get _player => ref.read(playerControllerProvider.notifier);

  /// Executes any [VoiceIntent] against application state.
  Future<ExecutionResult> execute(VoiceIntent intent) async {
    return await switch (intent) {
      Play() => _executePlay(),
      Pause() => _executePause(),
      Stop() => _executePause(),
      Next() => _executeNext(),
      Previous() => _executePrevious(),
      Restart() => _executeRestart(),
      SeekBy(:final seconds) => _executeSeekBy(seconds),
      SeekTo(:final seconds) => _executeSeekTo(seconds),
      VolumeUp() => _executeVolumeUp(),
      VolumeDown() => _executeVolumeDown(),
      VolumeSet(:final percent) => _executeVolumeSet(percent),
      Mute() => _executeMute(),
      Unmute() => _executeUnmute(),
      Shuffle(:final enable) => _executeShuffle(enable),
      Repeat(:final mode) => _executeRepeat(mode),
      Autoplay(:final enable) => _executeAutoplay(enable),
      Like() => _executeLike(),
      Unlike() => _executeUnlike(),
      PlayLiked() => _executePlayLiked(),
      PlayDownloaded() => _executePlayDownloaded(),
      PlayPlaylist(:final playlistName) => _executePlayPlaylist(playlistName),
      AddToPlaylist(:final playlistName) => _executeAddToPlaylist(playlistName),
      PlayRadio() => _executePlayRadio(),
      SleepTimer(:final minutes) => _executeSleepTimer(minutes),
      CancelSleepTimer() => _executeCancelSleepTimer(),
      WhatsPlaying() => _executeWhatsPlaying(),
      Help() => Future.value(const ExecutionSuccess(
          'You can say play, pause, next, volume, or search for any song.',
          displayText: 'Available commands: Play, Pause, Next, Previous, Volume, Liked songs, Sleep timer, Search',
        )),
      Cancel() => Future.value(const ExecutionSuccess('Cancelled.')),
      StopListening() => Future.value(const ExecutionSuccess('Stopped listening.')),
      PlaySearch(:final query, :final kind) => _executePlaySearch(query, kind),
      Open(:final screen) => Future.value(ExecutionSuccess('Opening ${screen.name}.')),
      OfflineMode(:final enable) => _executeOfflineMode(enable),
      DownloadCurrent() => _executeDownloadCurrent(),
    };
  }

  Future<ExecutionResult> _executePlay() async {
    final playerState = ref.read(playerControllerProvider);
    if (playerState.queue.currentTrack != null) {
      await _player.resume();
      return const ExecutionSuccess('Playing.');
    }

    final manifest = ref.read(downloadManagerProvider).manifest;
    if (manifest.tracks.isNotEmpty) {
      final tracks = manifest.tracks.values.map(_manifestToTrack).toList();
      await _player.playList(tracks, 0);
      return const ExecutionSuccess('Playing downloaded songs.');
    }

    return const ExecutionFailure('Nothing queued to play.');
  }

  Future<ExecutionResult> _executePause() async {
    await _player.pause();
    return const ExecutionSuccess('Paused.');
  }

  Future<ExecutionResult> _executeNext() async {
    await _player.skipNext();
    return const ExecutionSuccess('Next song.');
  }

  Future<ExecutionResult> _executePrevious() async {
    await _player.skipPrevious();
    return const ExecutionSuccess('Previous song.');
  }

  Future<ExecutionResult> _executeRestart() async {
    await _player.restart();
    return const ExecutionSuccess('Restarted.');
  }

  Future<ExecutionResult> _executeSeekBy(int seconds) async {
    await _player.seekRelative(Duration(seconds: seconds));
    if (seconds >= 0) {
      return ExecutionSuccess('Forward $seconds seconds.');
    } else {
      return ExecutionSuccess('Back ${-seconds} seconds.');
    }
  }

  Future<ExecutionResult> _executeSeekTo(int seconds) async {
    await _player.seekTo(Duration(seconds: seconds));
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return ExecutionSuccess('Seeked to $m:$s.');
  }

  Future<ExecutionResult> _executeVolumeUp() async {
    await _player.adjustVolume(0.1);
    final pct = (ref.read(playerControllerProvider).volume * 100).round();
    return ExecutionSuccess('Volume $pct percent.');
  }

  Future<ExecutionResult> _executeVolumeDown() async {
    await _player.adjustVolume(-0.1);
    final pct = (ref.read(playerControllerProvider).volume * 100).round();
    return ExecutionSuccess('Volume $pct percent.');
  }

  Future<ExecutionResult> _executeVolumeSet(int percent) async {
    await _player.setVolume(percent / 100.0);
    return ExecutionSuccess('Volume $percent percent.');
  }

  Future<ExecutionResult> _executeMute() async {
    await _player.setVolume(0.0);
    return const ExecutionSuccess('Muted.');
  }

  Future<ExecutionResult> _executeUnmute() async {
    await _player.setVolume(0.5);
    return const ExecutionSuccess('Unmuted.');
  }

  Future<ExecutionResult> _executeShuffle(bool enable) async {
    _player.setShuffle(enable);
    return ExecutionSuccess(enable ? 'Shuffle on.' : 'Shuffle off.');
  }

  Future<ExecutionResult> _executeRepeat(q.RepeatMode mode) async {
    _player.setRepeat(mode);
    final name = switch (mode) {
      q.RepeatMode.off => 'off',
      q.RepeatMode.all => 'all',
      q.RepeatMode.one => 'current song',
    };
    return ExecutionSuccess('Repeat $name.');
  }

  Future<ExecutionResult> _executeAutoplay(bool enable) async {
    await ref.read(autoplayEnabledProvider.notifier).setAutoplay(enable);
    return ExecutionSuccess(enable ? 'Autoplay on.' : 'Autoplay off.');
  }

  Future<ExecutionResult> _executeLike() async {
    final current = ref.read(playerControllerProvider).queue.currentTrack;
    if (current == null) {
      return const ExecutionFailure('No song playing to like.');
    }
    final likedIds = ref.read(likedIdsProvider).valueOrNull ?? {};
    if (!likedIds.contains(current.videoId)) {
      await ref.read(likedIdsProvider.notifier).toggleLike(current);
    }
    return const ExecutionSuccess('Added to liked songs.');
  }

  Future<ExecutionResult> _executeUnlike() async {
    final current = ref.read(playerControllerProvider).queue.currentTrack;
    if (current == null) {
      return const ExecutionFailure('No song playing to unlike.');
    }
    final likedIds = ref.read(likedIdsProvider).valueOrNull ?? {};
    if (likedIds.contains(current.videoId)) {
      await ref.read(likedIdsProvider.notifier).toggleLike(current);
    }
    return const ExecutionSuccess('Removed from liked songs.');
  }

  Future<ExecutionResult> _executePlayLiked() async {
    final isOffline = !ref.read(connectivityProvider).isOnline || ref.read(isOfflineModeProvider);
    try {
      final userApi = ref.read(userApiProvider);
      final page = await userApi.getLikes(limit: 50);
      final tracks = page.items.map((item) => item.track).toList();
      if (tracks.isEmpty) {
        return const ExecutionFailure('No liked songs found.');
      }
      List<Track> toPlay = tracks;
      if (isOffline) {
        final mgr = ref.read(downloadManagerProvider);
        toPlay = tracks.where((t) => mgr.isDownloaded(t.videoId)).toList();
        if (toPlay.isEmpty) {
          return const ExecutionFailure('No downloaded liked songs found.');
        }
      }
      await _player.playList(toPlay, 0);
      return const ExecutionSuccess('Playing your liked songs.');
    } catch (_) {
      return const ExecutionFailure('Could not load liked songs.');
    }
  }

  Future<ExecutionResult> _executePlayDownloaded() async {
    final manifest = ref.read(downloadManagerProvider).manifest;
    if (manifest.tracks.isEmpty) {
      return const ExecutionFailure('No downloaded songs found.');
    }
    final tracks = manifest.tracks.values.map(_manifestToTrack).toList();
    await _player.playList(tracks, 0);
    return const ExecutionSuccess('Playing downloaded songs.');
  }

  Future<ExecutionResult> _executePlayPlaylist(String name) async {
    final playlists = ref.read(playlistsProvider).valueOrNull ?? [];
    if (playlists.isEmpty) {
      return ExecutionFailure('No playlists found matching $name.');
    }

    final matches = EntityMatcher.matchPlaylist(name, playlists);
    if (matches.isEmpty) {
      return ExecutionFailure('Playlist $name not found.');
    }

    final target = matches.first.item;
    try {
      final userApi = ref.read(userApiProvider);
      final detail = await userApi.getPlaylist(target.id);
      final tracks = detail.tracks.items.map((i) => i.track).toList();
      if (tracks.isEmpty) {
        return ExecutionFailure('Playlist ${target.name} is empty.');
      }
      await _player.playList(tracks, 0);
      return ExecutionSuccess('Playing playlist ${target.name}.');
    } catch (_) {
      return ExecutionFailure('Could not open playlist ${target.name}.');
    }
  }

  Future<ExecutionResult> _executeAddToPlaylist(String name) async {
    final current = ref.read(playerControllerProvider).queue.currentTrack;
    if (current == null) {
      return const ExecutionFailure('No song playing to add.');
    }

    final playlists = ref.read(playlistsProvider).valueOrNull ?? [];
    final matches = EntityMatcher.matchPlaylist(name, playlists);
    if (matches.isEmpty) {
      return ExecutionFailure('Playlist $name not found.');
    }

    final target = matches.first.item;
    try {
      await ref.read(playlistDetailProvider(target.id).notifier).addTracks([current.videoId]);
      return ExecutionSuccess('Added to ${target.name}.');
    } catch (_) {
      return ExecutionFailure('Failed to add to ${target.name}.');
    }
  }

  Future<ExecutionResult> _executePlayRadio() async {
    final isOffline = !ref.read(connectivityProvider).isOnline || ref.read(isOfflineModeProvider);
    if (isOffline) {
      return const ExecutionFailure('Radio is not available offline.');
    }
    final current = ref.read(playerControllerProvider).queue.currentTrack;
    if (current == null) {
      return const ExecutionFailure('No song playing to start radio from.');
    }

    try {
      final discoveryApi = ref.read(discoveryApiProvider);
      final radioTracks = await discoveryApi.getWatchRadio(current.videoId);
      if (radioTracks.isEmpty) {
        return const ExecutionFailure('Could not generate radio.');
      }
      await _player.playList(radioTracks, 0);
      return ExecutionSuccess('Starting radio for ${current.title}.');
    } catch (_) {
      return const ExecutionFailure('Could not start radio.');
    }
  }

  Future<ExecutionResult> _executeSleepTimer(int minutes) async {
    ref.read(sleepTimerProvider.notifier).start(Duration(minutes: minutes));
    return ExecutionSuccess('Stop timer set for $minutes minutes.');
  }

  Future<ExecutionResult> _executeCancelSleepTimer() async {
    ref.read(sleepTimerProvider.notifier).cancel();
    return const ExecutionSuccess('Stop timer cancelled.');
  }

  Future<ExecutionResult> _executeWhatsPlaying() async {
    final current = ref.read(playerControllerProvider).queue.currentTrack;
    if (current == null) {
      return const ExecutionSuccess('Nothing is currently playing.');
    }
    return ExecutionSuccess('This is ${current.title} by ${current.artist}.');
  }

  Future<ExecutionResult> _executeOfflineMode(bool enable) async {
    ref.read(offlineModeProvider.notifier).setManualOffline(enable);
    return ExecutionSuccess(enable ? 'Offline mode on.' : 'Offline mode off.');
  }

  Future<ExecutionResult> _executeDownloadCurrent() async {
    final current = ref.read(playerControllerProvider).queue.currentTrack;
    if (current == null) {
      return const ExecutionFailure('No song playing to download.');
    }
    await ref.read(downloadManagerProvider).enqueueTrack(current);
    return ExecutionSuccess('Downloading ${current.title}.');
  }

  Future<ExecutionResult> _executePlaySearch(String query, SearchKind? kind) async {
    final isOffline = !ref.read(connectivityProvider).isOnline || ref.read(isOfflineModeProvider);

    if (isOffline) {
      final manifest = ref.read(downloadManagerProvider).manifest;
      final qLower = query.toLowerCase();
      final matching = manifest.tracks.values.where((t) =>
          t.title.toLowerCase().contains(qLower) ||
          t.artist.toLowerCase().contains(qLower)).toList();

      if (matching.isEmpty) {
        return const ExecutionFailure('Song not found in offline downloads.');
      }

      final track = _manifestToTrack(matching.first);
      await _player.playTrack(track);
      return ExecutionSuccess('Playing ${track.title}.');
    }

    try {
      final discoveryApi = ref.read(discoveryApiProvider);
      final filterStr = switch (kind) {
        SearchKind.album => 'albums',
        SearchKind.artist => 'artists',
        _ => 'songs',
      };

      final searchFilter = await discoveryApi.searchFilter(query, filterStr);
      final results = searchFilter.results;
      if (results.isEmpty) {
        return ExecutionFailure('No songs found for $query.');
      }

      if (results.length >= 2) {
        final r1 = results[0];
        final r2 = results[1];
        if (r1.title.toLowerCase() != r2.title.toLowerCase()) {
          final t1 = _mediaItemToTrack(r1);
          final t2 = _mediaItemToTrack(r2);
          return ExecutionDisambiguationRequired(
            spokenReply: 'I found two songs. Say one for ${r1.title}, or two for ${r2.title}.',
            candidates: [t1, t2],
          );
        }
      }

      final top = _mediaItemToTrack(results.first);
      await _player.playTrack(top);
      return ExecutionSuccess('Playing ${top.title}.');
    } catch (_) {
      return ExecutionFailure('Search failed for $query.');
    }
  }

  Track _manifestToTrack(ManifestTrack mt) {
    return Track(
      videoId: mt.videoId,
      title: mt.title,
      artist: mt.artist,
      artists: mt.artists.map((a) => Artist(id: '', name: a)).toList(),
      album: mt.album,
      albumId: mt.albumId,
      durationSeconds: mt.durationSeconds,
      thumbnail: null,
      isExplicit: false,
    );
  }

  Track _mediaItemToTrack(MediaItem mi) {
    return Track(
      videoId: mi.videoId ?? mi.id,
      title: mi.title,
      artist: mi.subtitle ?? 'Unknown',
      artists: const [],
      album: null,
      durationSeconds: mi.durationSeconds,
      thumbnail: mi.thumbnail,
      isExplicit: mi.isExplicit,
    );
  }
}
