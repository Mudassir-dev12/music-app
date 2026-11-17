import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../api/models.dart';

/// Wraps [just_audio.AudioPlayer] as an [audio_service.BaseAudioHandler].
///
/// Handles single-source playback (URLs resolved lazily with tickets) and
/// maps lock-screen / notification controls to callbacks or internal state.
class MelodiaAudioHandler extends BaseAudioHandler with SeekHandler {
  MelodiaAudioHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _init();
  }

  final AudioPlayer _player;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;

  AudioPlayer get player => _player;

  Future<void> _init() async {
    if (!kIsWeb) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      } catch (_) {
        // Audio session configuration failed or unsupported
      }
    }

    // Broadcast playback events to AudioService
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 3],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }

  void updateCurrentMediaItem(Track track, Duration duration) {
    mediaItem.add(
      MediaItem(
        id: track.videoId,
        album: track.album ?? 'Single',
        title: track.title,
        artist: track.artist,
        duration: duration,
        artUri: track.thumbnail != null ? Uri.tryParse(track.thumbnail!) : null,
      ),
    );
  }

  Future<Duration?> playUrl(String url, {Duration? initialPosition}) async {
    try {
      final setUrlFuture = _player.setUrl(url, initialPosition: initialPosition);
      _player.play();
      final duration = await setUrlFuture;
      return duration;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}

