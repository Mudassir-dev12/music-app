import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../api/models.dart';

/// Buffering configuration named constants.
/// - kMinBufferDuration: minimum audio buffered before playback continues (4s).
/// - kMaxBufferDuration: player forward buffer cap (60s forward buffer to absorb drops).
/// - kBufferForPlaybackDuration: playback starts after ~1s of audio is buffered for instant feel.
/// - kBufferForPlaybackAfterRebufferDuration: after a network stall, wait for 3s to ride out network drops.
/// - kDarwinPreferredForwardBufferDuration: iOS preferred forward buffer duration (45s).
const Duration kMinBufferDuration = Duration(seconds: 4);
const Duration kMaxBufferDuration = Duration(seconds: 60);
const Duration kBufferForPlaybackDuration = Duration(milliseconds: 1000);
const Duration kBufferForPlaybackAfterRebufferDuration = Duration(milliseconds: 3000);
const Duration kDarwinPreferredForwardBufferDuration = Duration(seconds: 45);

/// Wraps [just_audio.AudioPlayer] as an [audio_service.BaseAudioHandler].
///
/// Handles single-source and concatenating playback (URLs resolved lazily with tickets) and
/// maps lock-screen / notification controls to callbacks or internal state.
class MelodiaAudioHandler extends BaseAudioHandler with SeekHandler {
  MelodiaAudioHandler({AudioPlayer? player})
      : _player = player ??
            AudioPlayer(
              audioLoadConfiguration: const AudioLoadConfiguration(
                androidLoadControl: AndroidLoadControl(
                  minBufferDuration: kMinBufferDuration,
                  maxBufferDuration: kMaxBufferDuration,
                  bufferForPlaybackDuration: kBufferForPlaybackDuration,
                  bufferForPlaybackAfterRebufferDuration: kBufferForPlaybackAfterRebufferDuration,
                ),
                darwinLoadControl: DarwinLoadControl(
                  automaticallyWaitsToMinimizeStalling: false,
                  preferredForwardBufferDuration: kDarwinPreferredForwardBufferDuration,
                ),
              ),
            ) {
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

  Future<Duration?> playSource(AudioSource source, {Duration? initialPosition}) async {
    try {
      final duration = await _player.setAudioSource(source, initialPosition: initialPosition);
      await _player.play();
      return duration;
    } catch (e) {
      rethrow;
    }
  }

  Future<Duration?> playUrl(String url, {Duration? initialPosition}) async {
    try {
      final duration = await _player.setUrl(url);
      if (initialPosition != null && initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }
      await _player.play();
      return duration;
    } catch (e) {
      rethrow;
    }
  }

  Future<Duration?> playFile(String filePath, {Duration? initialPosition}) async {
    try {
      final duration = await _player.setFilePath(filePath);
      if (initialPosition != null && initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }
      await _player.play();
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

