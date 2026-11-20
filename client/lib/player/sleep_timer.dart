import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player_controller.dart';

class SleepTimerState {
  const SleepTimerState({
    this.remaining,
    this.isActive = false,
    this.targetEndTime,
  });

  final Duration? remaining;
  final bool isActive;
  final DateTime? targetEndTime;

  int get remainingMinutes => (remaining?.inSeconds ?? 0) ~/ 60;
  int get remainingSeconds => (remaining?.inSeconds ?? 0) % 60;

  SleepTimerState copyWith({
    Duration? remaining,
    bool? isActive,
    DateTime? targetEndTime,
    bool clearRemaining = false,
  }) {
    return SleepTimerState(
      remaining: clearRemaining ? null : (remaining ?? this.remaining),
      isActive: isActive ?? this.isActive,
      targetEndTime: clearRemaining ? null : (targetEndTime ?? this.targetEndTime),
    );
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
        SleepTimerController.new);

class SleepTimerController extends Notifier<SleepTimerState> {
  Timer? _ticker;
  double? _savedVolume;
  bool _isFading = false;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const SleepTimerState();
  }

  void start(Duration duration) {
    _ticker?.cancel();
    _isFading = false;
    _savedVolume = null;

    final target = DateTime.now().add(duration);
    state = SleepTimerState(
      remaining: duration,
      isActive: true,
      targetEndTime: target,
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now();
      final diff = target.difference(now);

      if (diff <= Duration.zero) {
        timer.cancel();
        await _completeFadeAndPause();
      } else {
        state = state.copyWith(remaining: diff);
        // Start 3-second fadeout when <= 3 seconds remain
        if (diff.inSeconds <= 3 && !_isFading) {
          _startFadeOut(diff.inMilliseconds);
        }
      }
    });
  }

  void _startFadeOut(int remainingMs) {
    _isFading = true;
    final player = ref.read(playerControllerProvider.notifier);
    final currentVol = ref.read(playerControllerProvider).volume;
    _savedVolume = currentVol;

    const steps = 6;
    final interval = remainingMs ~/ steps;
    int currentStep = 0;

    Timer.periodic(Duration(milliseconds: interval.clamp(100, 1000)), (t) {
      currentStep++;
      if (currentStep >= steps || !state.isActive) {
        t.cancel();
      } else {
        final fraction = (steps - currentStep) / steps;
        player.setVolume(currentVol * fraction);
      }
    });
  }

  Future<void> _completeFadeAndPause() async {
    final player = ref.read(playerControllerProvider.notifier);
    await player.pause();
    if (_savedVolume != null) {
      await player.setVolume(_savedVolume!);
    }
    _isFading = false;
    state = const SleepTimerState();
  }

  void cancel() {
    _ticker?.cancel();
    if (_isFading && _savedVolume != null) {
      ref.read(playerControllerProvider.notifier).setVolume(_savedVolume!);
    }
    _isFading = false;
    state = const SleepTimerState();
  }
}

