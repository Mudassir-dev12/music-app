import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/discovery_api.dart';
import '../api/errors.dart';
import '../api/models.dart';
import '../core/connectivity/connectivity_controller.dart';
import '../core/platform/media_session.dart';
import 'audio_handler.dart';
import 'audio_url_service.dart';
import 'autoplay_controller.dart';
import 'events.dart';
import 'persistence.dart';
import 'player_state.dart';
import 'queue.dart' as q;

final audioHandlerProvider = Provider<MelodiaAudioHandler>((ref) {
  return MelodiaAudioHandler();
});

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerStateData>(PlayerController.new);

class PlayerController extends Notifier<PlayerStateData> {
  MelodiaAudioHandler get _audioHandler => ref.read(audioHandlerProvider);
  AudioUrlService get _urlService => ref.read(audioUrlServiceProvider);
  PersistenceService get _persistence => ref.read(persistenceServiceProvider);
  ApiClient get _apiClient => ref.read(apiClientProvider);

  int _consecutiveErrors = 0;
  String? _lastErrorVideoId;
  bool _warmedUpNextTrack = false;
  bool _emitted30sEvent = false;
  double _lastVolumeBeforeMute = 1.0;
  DateTime _lastPositionUpdateTime = DateTime.now();
  String? toastMessage;

  // Auto-resume state on network recovery
  bool _wasPlayingBeforeNetworkFailure = false;
  Duration _failurePosition = Duration.zero;
  int _autoResumeAttempts = 0;

  @visibleForTesting
  bool get wasPlayingBeforeNetworkFailure => _wasPlayingBeforeNetworkFailure;
  @visibleForTesting
  int get autoResumeAttempts => _autoResumeAttempts;
  @visibleForTesting
  void simulateNetworkFailureForTesting(Duration position) {
    _wasPlayingBeforeNetworkFailure = true;
    _failurePosition = position;
  }

  @override
  PlayerStateData build() {
    final initial = PlayerStateData.initial();
    _init();
    return initial;
  }

  Future<void> _init() async {
    _audioHandler.onSkipToNext = skipNext;
    _audioHandler.onSkipToPrevious = skipPrevious;

    // Listen to position changes throttled to <= 4 Hz (250 ms)
    _audioHandler.positionStream.listen((pos) {
      final now = DateTime.now();
      if (now.difference(_lastPositionUpdateTime).inMilliseconds >= 250) {
        _lastPositionUpdateTime = now;
        state = state.copyWith(position: pos);
        _checkWarmUpAndEvents(pos);
        _persistence.saveStateDebounced(state);
      }
    });

    _audioHandler.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    // Listen to player state (completed, playing, buffering, etc.)
    _audioHandler.playerStateStream.listen((ps) {
      if (ps.processingState.name == 'completed') {
        _onTrackEnded();
      }
    });

    // Listen to connectivity restoration for auto-resume
    ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      if (previous?.isOnline == false && next.isOnline) {
        _onConnectivityRestored();
      }
    });

    // Restore state from persistence as PAUSED
    final restored = await _persistence.restoreState();
    if (restored != null && restored.queue.isNotEmpty) {
      state = state.copyWith(
        queue: restored.queue,
        position: restored.position,
        volume: restored.volume,
        status: PlayerStatus.paused,
      );
      final current = restored.queue.currentTrack;
      if (current != null) {
        _updateMetadata(current, restored.position);
      }
    }
  }

  void _checkWarmUpAndEvents(Duration pos) {
    final current = state.queue.currentTrack;
    if (current == null || state.duration <= Duration.zero) return;

    final progressFraction = pos.inMilliseconds / state.duration.inMilliseconds;

    // Check 30s or 50% event
    if (!_emitted30sEvent && (pos.inSeconds >= 30 || progressFraction >= 0.5)) {
      _emitted30sEvent = true;
      emitPlayerEvent(PlayerEvent(
        type: PlayerEventType.track30s,
        videoId: current.videoId,
        timestamp: DateTime.now(),
      ));
    }

    // Warm-up next track early (after 5 seconds or 10% progress) so skip/next is instant
    if (!_warmedUpNextTrack && (pos.inSeconds >= 5 || progressFraction >= 0.1)) {
      _warmedUpNextTrack = true;
      _warmUpNextTrack();
    }
  }

  void _warmUpNextTrack() {
    final queue = state.queue;
    Track? nextTrack;
    if (queue.playNextQueue.isNotEmpty) {
      nextTrack = queue.playNextQueue.first;
    } else if (queue.currentIndex + 1 < queue.queue.length) {
      nextTrack = queue.queue[queue.currentIndex + 1];
    } else if (queue.repeat == q.RepeatMode.all && queue.queue.isNotEmpty) {
      nextTrack = queue.queue.first;
    }

    if (nextTrack != null) {
      final vid = nextTrack.videoId;
      _urlService.urlFor(vid).then((url) {
        // HEAD request to prime backend stream cache
        _apiClient.head(url).catchError((_) => null);
      }).catchError((_) => null);
    }
  }

  Future<void> playList(List<Track> tracks, int startIndex) async {
    final newQueue = q.playList(state.queue, tracks, startIndex);
    state = state.copyWith(queue: newQueue);
    await _loadAndPlayCurrent();
  }

  Future<void> playQueue(List<Track> tracks, {int initialIndex = 0}) async {
    await playList(tracks, initialIndex);
  }

  Future<void> playTrack(Track track) async {
    await playList([track], 0);
  }

  Future<void> _loadAndPlayCurrent({Duration? resumeAt}) async {
    final current = state.queue.currentTrack;
    if (current == null) {
      state = state.copyWith(status: PlayerStatus.idle);
      return;
    }

    state = state.copyWith(
      status: PlayerStatus.loading,
      clearError: true,
    );

    _warmedUpNextTrack = false;
    _emitted30sEvent = false;

    try {
      final url = await _urlService.urlFor(current.videoId);
      final duration = await _audioHandler.playUrl(url, initialPosition: resumeAt);

      _consecutiveErrors = 0;
      _lastErrorVideoId = null;
      _wasPlayingBeforeNetworkFailure = false;
      _autoResumeAttempts = 0;

      state = state.copyWith(
        status: PlayerStatus.playing,
        duration: duration ?? Duration(seconds: current.durationSeconds ?? 0),
        position: resumeAt ?? Duration.zero,
      );

      _updateMetadata(current, duration ?? Duration.zero);
      emitPlayerEvent(PlayerEvent(
        type: PlayerEventType.trackStarted,
        videoId: current.videoId,
        timestamp: DateTime.now(),
      ));

      _persistence.addToRecentlyPlayed(current);
      _persistence.saveStateDebounced(state);

      // Immediately warm up next track so transition / skip is instant
      _warmUpNextTrack();
    } on RateLimitError catch (e) {
      state = state.copyWith(
        status: PlayerStatus.paused,
        errorMessage: 'Bandwidth limit reached. Try again in ${e.retryAfterSeconds}s',
      );
    } catch (e) {
      final isOffline = !ref.read(connectivityProvider).isOnline;
      if (isOffline || isNetworkError(e)) {
        _wasPlayingBeforeNetworkFailure = true;
        _failurePosition = resumeAt ?? state.position;
      }
      await _handlePlaybackError(current, resumeAt ?? state.position);
    }
  }

  Future<void> _handlePlaybackError(Track track, Duration position) async {
    final isOffline = !ref.read(connectivityProvider).isOnline;
    if (isOffline) {
      _wasPlayingBeforeNetworkFailure = true;
      _failurePosition = position;
      state = state.copyWith(
        status: PlayerStatus.paused,
        errorMessage: 'Connection lost. Playback will resume when back online.',
      );
      return;
    }

    _consecutiveErrors++;

    if (_lastErrorVideoId != track.videoId) {
      // First error for this track: request fresh ticket and retry once
      _lastErrorVideoId = track.videoId;
      _urlService.invalidate(track.videoId);
      try {
        await _loadAndPlayCurrent(resumeAt: position);
        return;
      } catch (_) {
        // Second attempt failed
      }
    }

    // Second failure for same track
    state = state.copyWith(
      errorMessage: 'This song is unavailable',
    );

    if (_consecutiveErrors >= 3) {
      // After 3 consecutive failures total, stop
      state = state.copyWith(status: PlayerStatus.error);
      await _audioHandler.stop();
      return;
    }

    // Skip to next track
    await skipNext();
  }

  Future<void> _onConnectivityRestored() async {
    if (!_wasPlayingBeforeNetworkFailure) return;

    if (_autoResumeAttempts >= 5) {
      _wasPlayingBeforeNetworkFailure = false;
      state = state.copyWith(
        status: PlayerStatus.paused,
        errorMessage: 'Playback paused. Tap play to retry.',
      );
      return;
    }

    _autoResumeAttempts++;
    final current = state.queue.currentTrack;
    if (current != null) {
      _urlService.invalidate(current.videoId);
      await _loadAndPlayCurrent(resumeAt: _failurePosition);
    }
  }

  Future<void> togglePlayPause() async {
    if (!kIsWeb) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    if (state.status == PlayerStatus.playing) {
      await pause();
    } else if (state.status == PlayerStatus.paused) {
      await resume();
    } else if (state.queue.currentTrack != null) {
      await _loadAndPlayCurrent(resumeAt: state.position);
    }
  }

  Future<void> pause() async {
    _wasPlayingBeforeNetworkFailure = false;
    _autoResumeAttempts = 0;
    await _audioHandler.pause();
    state = state.copyWith(status: PlayerStatus.paused);
    MediaSessionService.updatePlaybackState(playing: false);
    _persistence.saveStateDebounced(state);
  }

  Future<void> resume() async {
    await _audioHandler.play();
    state = state.copyWith(status: PlayerStatus.playing);
    MediaSessionService.updatePlaybackState(playing: true);
    _persistence.saveStateDebounced(state);
  }

  Future<void> seekTo(Duration position) async {
    state = state.copyWith(position: position);
    await _audioHandler.seek(position);
    _persistence.saveStateDebounced(state);
  }

  Future<void> seekRelative(Duration offset) async {
    final target = state.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > state.duration ? state.duration : target);
    await seekTo(clamped);
  }

  Future<void> skipNext() async {
    final newQueue = q.nextTrack(state.queue);
    if (newQueue.currentIndex == -1) {
      // End of queue with repeat off — check if autoplay is enabled
      final autoplayEnabled = ref.read(autoplayEnabledProvider);
      final lastTrack = state.queue.currentTrack;
      if (autoplayEnabled && lastTrack != null) {
        final discoveryApi = ref.read(discoveryApiProvider);
        final candidates = await getAutoplayCandidates(
          discoveryApi: discoveryApi,
          seedTrack: lastTrack,
          existingQueue: state.queue.queue,
        );
        if (candidates.isNotEmpty) {
          final updatedList = [...state.queue.queue, ...candidates];
          final nextIndex = state.queue.queue.length;
          final updatedQueue = state.queue.copyWith(
            queue: updatedList,
            currentIndex: nextIndex,
          );
          state = state.copyWith(queue: updatedQueue);
          await _loadAndPlayCurrent();
          return;
        }
      }

      state = state.copyWith(
        queue: newQueue.copyWith(currentIndex: 0),
        status: PlayerStatus.paused,
      );
      await _audioHandler.stop();
      return;
    }
    state = state.copyWith(queue: newQueue);
    await _loadAndPlayCurrent();
  }

  Future<void> skipPrevious() async {
    final newQueue = q.previousTrack(state.queue, state.position);
    state = state.copyWith(queue: newQueue);
    await _loadAndPlayCurrent();
  }

  void _onTrackEnded() {
    final current = state.queue.currentTrack;
    if (current != null) {
      emitPlayerEvent(PlayerEvent(
        type: PlayerEventType.trackEnded,
        videoId: current.videoId,
        timestamp: DateTime.now(),
      ));
    }
    skipNext();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _audioHandler.setVolume(clamped);
    _persistence.saveStateDebounced(state);
  }

  Future<void> adjustVolume(double delta) async {
    await setVolume(state.volume + delta);
  }

  Future<void> toggleMute() async {
    if (state.volume > 0.0) {
      _lastVolumeBeforeMute = state.volume;
      await setVolume(0.0);
    } else {
      await setVolume(_lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 0.5);
    }
  }

  void toggleShuffle() {
    final newQueue = q.toggleShuffle(state.queue);
    state = state.copyWith(queue: newQueue);
    _persistence.saveStateDebounced(state);
  }

  void cycleRepeat() {
    final newQueue = q.cycleRepeat(state.queue);
    state = state.copyWith(queue: newQueue);
    _persistence.saveStateDebounced(state);
  }

  void enqueueNext(Track track) {
    final newQueue = q.enqueueNext(state.queue, track);
    state = state.copyWith(queue: newQueue);
    _persistence.saveStateDebounced(state);
  }

  void enqueueLast(Track track) {
    final newQueue = q.enqueueLast(state.queue, track);
    state = state.copyWith(queue: newQueue);
    _persistence.saveStateDebounced(state);
  }

  void removeAt(int index) {
    final newQueue = q.removeAt(state.queue, index);
    state = state.copyWith(queue: newQueue);
    _persistence.saveStateDebounced(state);
  }

  void move(int from, int to) {
    final newQueue = q.move(state.queue, from, to);
    state = state.copyWith(queue: newQueue);
    _persistence.saveStateDebounced(state);
  }

  void clearPlayNext() {
    state = state.copyWith(
      queue: state.queue.copyWith(playNextQueue: const []),
    );
    _persistence.saveStateDebounced(state);
  }

  void _updateMetadata(Track track, Duration duration) {
    _audioHandler.updateCurrentMediaItem(track, duration);
    MediaSessionService.updateMetadata(
      title: track.title,
      artist: track.artist,
      album: track.album ?? 'Single',
      artworkUrl: track.thumbnail,
    );
    MediaSessionService.updatePlaybackState(playing: state.isPlaying);
  }
}
