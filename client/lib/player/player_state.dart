import 'queue.dart';

enum PlayerStatus { idle, loading, buffering, playing, paused, error }

class PlayerStateData {
  const PlayerStateData({
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.errorMessage,
    this.showLoadingIndicator = false,
    required this.queue,
  });

  final PlayerStatus status;
  final Duration position;
  final Duration duration;
  final double volume;
  final String? errorMessage;
  final bool showLoadingIndicator;
  final QueueState queue;

  bool get isPlaying =>
      status == PlayerStatus.playing ||
      status == PlayerStatus.loading ||
      status == PlayerStatus.buffering;
  bool get isBuffering => status == PlayerStatus.buffering;
  bool get isLoading => showLoadingIndicator;

  PlayerStateData copyWith({
    PlayerStatus? status,
    Duration? position,
    Duration? duration,
    double? volume,
    String? errorMessage,
    bool? showLoadingIndicator,
    bool clearError = false,
    QueueState? queue,
  }) {
    return PlayerStateData(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showLoadingIndicator: showLoadingIndicator ?? this.showLoadingIndicator,
      queue: queue ?? this.queue,
    );
  }

  static PlayerStateData initial() => PlayerStateData(
        queue: QueueState.empty(),
      );
}

