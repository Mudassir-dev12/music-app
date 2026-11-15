import 'queue.dart';

enum PlayerStatus { idle, loading, buffering, playing, paused, error }

class PlayerStateData {
  const PlayerStateData({
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.errorMessage,
    required this.queue,
  });

  final PlayerStatus status;
  final Duration position;
  final Duration duration;
  final double volume;
  final String? errorMessage;
  final QueueState queue;

  bool get isPlaying => status == PlayerStatus.playing;
  bool get isBuffering => status == PlayerStatus.buffering;
  bool get isLoading => status == PlayerStatus.loading;

  PlayerStateData copyWith({
    PlayerStatus? status,
    Duration? position,
    Duration? duration,
    double? volume,
    String? errorMessage,
    bool clearError = false,
    QueueState? queue,
  }) {
    return PlayerStateData(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      queue: queue ?? this.queue,
    );
  }

  static PlayerStateData initial() => PlayerStateData(
        queue: QueueState.empty(),
      );
}
