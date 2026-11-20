import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../player/player_controller.dart';
import 'command_deduper.dart';
import 'intent_executor.dart';
import 'intent_parser.dart';
import 'speech_port.dart';
import 'speech_port_plugin.dart';
import 'voice_intent.dart';
import 'voice_settings.dart';

enum VoiceStatus {
  idle,
  needsPermission,
  armed,
  restarting,
  listening,
  processing,
  confirming,
  executing,
  speaking,
  paused,
  error,
}

class VoiceState {
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.lastTranscript,
    this.lastReply,
    this.errorMessage,
    this.isRideMode = false,
    this.isContinuous = false,
    this.isEarbudsConnected = false,
    this.consecutiveFailures = 0,
    this.disambiguationCandidates,
  });

  final VoiceStatus status;
  final String? lastTranscript;
  final String? lastReply;
  final String? errorMessage;
  final bool isRideMode;
  final bool isContinuous;
  final bool isEarbudsConnected;
  final int consecutiveFailures;
  final List<Track>? disambiguationCandidates;

  bool get isListening =>
      status == VoiceStatus.listening ||
      status == VoiceStatus.armed ||
      status == VoiceStatus.restarting;

  VoiceState copyWith({
    VoiceStatus? status,
    String? lastTranscript,
    String? lastReply,
    String? errorMessage,
    bool? isRideMode,
    bool? isContinuous,
    bool? isEarbudsConnected,
    int? consecutiveFailures,
    List<Track>? disambiguationCandidates,
    bool clearDisambiguation = false,
    bool clearError = false,
  }) {
    return VoiceState(
      status: status ?? this.status,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastReply: lastReply ?? this.lastReply,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRideMode: isRideMode ?? this.isRideMode,
      isContinuous: isContinuous ?? this.isContinuous,
      isEarbudsConnected: isEarbudsConnected ?? this.isEarbudsConnected,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      disambiguationCandidates: clearDisambiguation
          ? null
          : (disambiguationCandidates ?? this.disambiguationCandidates),
    );
  }
}

final speechRecognizerProvider = Provider<SpeechRecognizerPort>((ref) {
  return SpeechToTextPluginRecognizer();
});

final speechSynthesizerProvider = Provider<SpeechSynthesizerPort>((ref) {
  return FlutterTtsSynthesizer();
});

final audioRouteProvider = Provider<AudioRoutePort>((ref) {
  return AudioRoutePlugin();
});

final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceState>(VoiceController.new);

class VoiceController extends Notifier<VoiceState> {
  SpeechRecognizerPort get _recognizer => ref.read(speechRecognizerProvider);
  SpeechSynthesizerPort get _synthesizer => ref.read(speechSynthesizerProvider);
  AudioRoutePort get _audioRoute => ref.read(audioRouteProvider);

  final CommandDeduper _deduper = CommandDeduper();
  double? _preDuckVolume;
  bool _isDucked = false;
  Timer? _restartTimer;
  StreamSubscription<bool>? _routeSub;

  @override
  VoiceState build() {
    _initRouteListener();
    ref.onDispose(() {
      _restartTimer?.cancel();
      _routeSub?.cancel();
    });
    return const VoiceState();
  }

  void _initRouteListener() {
    _routeSub = _audioRoute.onRouteChanged.listen((connected) {
      state = state.copyWith(isEarbudsConnected: connected);
    });
    _audioRoute.isHeadsetOrBluetoothConnected().then((connected) {
      state = state.copyWith(isEarbudsConnected: connected);
    });
  }

  /// Starts listening.
  /// If [rideMode] is true, enters hands-free continuous mode with strict parser.
  Future<void> startListening({
    bool rideMode = false,
    bool continuous = false,
  }) async {
    _restartTimer?.cancel();

    final hasPerm = await _recognizer.requestPermission();
    if (!hasPerm) {
      state = state.copyWith(
        status: VoiceStatus.needsPermission,
        errorMessage: 'Microphone permission is required for voice control.',
      );
      return;
    }

    final isEarbuds = await _audioRoute.isHeadsetOrBluetoothConnected();
    state = state.copyWith(
      status: VoiceStatus.armed,
      isRideMode: rideMode,
      isContinuous: continuous || rideMode,
      isEarbudsConnected: isEarbuds,
      clearError: true,
    );

    await _beginListeningSession();
  }

  Future<void> _beginListeningSession() async {
    if (!state.isEarbudsConnected) {
      _duckAudio();
    }

    state = state.copyWith(status: VoiceStatus.listening);

    final settings = ref.read(voiceSettingsProvider);
    final locale = settings.preferredLanguage == 'auto'
        ? null
        : (settings.preferredLanguage == 'ur' ? 'ur_PK' : 'en_US');

    await _recognizer.startListening(
      onResult: _handleTranscript,
      onError: _handleRecognitionError,
      localeId: locale,
      continuous: state.isContinuous,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
    );
  }

  /// Stops voice listening completely.
  Future<void> stopListening() async {
    _restartTimer?.cancel();
    await _recognizer.stopListening();
    _unduckAudio();
    state = state.copyWith(
      status: VoiceStatus.idle,
      isContinuous: false,
      clearDisambiguation: true,
    );
  }

  /// Cancels any active utterance or disambiguation.
  Future<void> cancel() async {
    await _recognizer.cancelListening();
    _unduckAudio();
    state = state.copyWith(
      status: state.isContinuous ? VoiceStatus.armed : VoiceStatus.idle,
      clearDisambiguation: true,
    );
    if (state.isContinuous) {
      _scheduleRestart(const Duration(milliseconds: 300));
    }
  }

  void _duckAudio() {
    if (_isDucked) return;
    try {
      final currentVol = ref.read(playerControllerProvider).volume;
      _preDuckVolume = currentVol;
      ref.read(playerControllerProvider.notifier).setVolume(currentVol * 0.3);
      _isDucked = true;
    } catch (_) {}
  }

  void _unduckAudio() {
    if (!_isDucked) return;
    try {
      if (_preDuckVolume != null) {
        ref.read(playerControllerProvider.notifier).setVolume(_preDuckVolume!);
        _preDuckVolume = null;
      }
      _isDucked = false;
    } catch (_) {}
  }

  Future<void> _handleTranscript(String transcript) async {
    if (transcript.trim().isEmpty) return;

    state = state.copyWith(
      status: VoiceStatus.processing,
      lastTranscript: transcript,
    );

    // 1. Check if disambiguation is waiting for user choice
    if (state.disambiguationCandidates != null &&
        state.disambiguationCandidates!.isNotEmpty) {
      final handled = await _handleDisambiguationChoice(transcript);
      if (handled) return;
    }

    // 2. Local rule-based parsing
    final settings = ref.read(voiceSettingsProvider);
    final parseResult = IntentParser.parse(
      transcript,
      language: settings.preferredLanguage,
      mode: state.isRideMode ? ParserMode.strict : ParserMode.normal,
      allowSearchWithoutWakeWord: settings.allowSearchWithoutWakeWord,
    );

    switch (parseResult) {
      case Matched(:final intent):
        await _executeIntent(intent);
      case Ambiguous(:final candidates):
        if (candidates.isNotEmpty) {
          await _executeIntent(candidates.first);
        }
      case NoMatch():
        // Unknown command
        if (!state.isRideMode) {
          await _speakFeedback('Sorry, I did not catch that.');
        }
        _afterActionCycle();
    }
  }

  Future<bool> _handleDisambiguationChoice(String text) async {
    final lower = text.trim().toLowerCase();
    final candidates = state.disambiguationCandidates!;

    Track? selected;
    if (lower == 'one' || lower == '1' || lower == 'first' || lower == 'ek' || lower == 'ایک') {
      selected = candidates.first;
    } else if (lower == 'two' || lower == '2' || lower == 'second' || lower == 'do' || lower == 'دو') {
      if (candidates.length >= 2) selected = candidates[1];
    } else if (lower == 'cancel' || lower == 'chordo' || lower == 'کینسل') {
      state = state.copyWith(clearDisambiguation: true);
      await _speakFeedback('Cancelled.');
      _afterActionCycle();
      return true;
    }

    if (selected != null) {
      state = state.copyWith(clearDisambiguation: true);
      await ref.read(playerControllerProvider.notifier).playTrack(selected);
      await _speakFeedback('Playing ${selected.title}.');
      _afterActionCycle();
      return true;
    }

    return false;
  }

  Future<void> _executeIntent(VoiceIntent intent) async {
    if (!_deduper.shouldExecute(intent)) {
      _afterActionCycle();
      return;
    }

    if (intent is StopListening) {
      await _speakFeedback('Stopped listening.');
      await stopListening();
      return;
    }

    state = state.copyWith(status: VoiceStatus.executing);

    final executor = IntentExecutor(ref);
    final result = await executor.execute(intent);

    state = state.copyWith(lastReply: result.spokenReply);

    switch (result) {
      case ExecutionDisambiguationRequired(:final candidates, :final spokenReply):
        state = state.copyWith(
          status: VoiceStatus.confirming,
          disambiguationCandidates: candidates,
        );
        await _speakFeedback(spokenReply);
        // Do not auto-unduck or restart loop until user picks 1 or 2
        _scheduleRestart(const Duration(milliseconds: 500));

      case ExecutionSuccess(:final spokenReply):
        final settings = ref.read(voiceSettingsProvider);
        if (settings.confirmSpoken) {
          await _speakFeedback(spokenReply);
        }
        _afterActionCycle();

      case ExecutionFailure(:final spokenReply):
        final settings = ref.read(voiceSettingsProvider);
        if (settings.confirmSpoken) {
          await _speakFeedback(spokenReply);
        }
        _afterActionCycle();
    }
  }

  Future<void> _speakFeedback(String text) async {
    state = state.copyWith(status: VoiceStatus.speaking);
    final completer = Completer<void>();
    final sub = _synthesizer.onCompletion.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    await _synthesizer.speak(text);

    // Timeout fallback after 4 seconds
    await Future.any<void>([
      completer.future,
      Future<void>.delayed(const Duration(seconds: 4)),
    ]);
    await sub.cancel();
  }

  void _afterActionCycle() {
    _unduckAudio();
    state = state.copyWith(consecutiveFailures: 0);

    if (state.isContinuous) {
      _scheduleRestart(const Duration(milliseconds: 300));
    } else {
      state = state.copyWith(status: VoiceStatus.idle);
    }
  }

  void _handleRecognitionError(VoiceError error) {
    debugPrint('Voice recognition error: $error');

    final nextFailures = state.consecutiveFailures + 1;
    state = state.copyWith(
      consecutiveFailures: nextFailures,
      errorMessage: error.message,
    );

    if (error.kind == VoiceErrorKind.permissionDenied) {
      state = state.copyWith(status: VoiceStatus.needsPermission);
      _unduckAudio();
      return;
    }

    // After 5 consecutive failures, pause continuous restart
    if (nextFailures >= 5) {
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Microphone had multiple errors. Tap to resume listening.',
      );
      _unduckAudio();
      return;
    }

    if (state.isContinuous) {
      _scheduleRestart(const Duration(milliseconds: 1000));
    } else {
      _unduckAudio();
      state = state.copyWith(status: VoiceStatus.idle);
    }
  }

  void _scheduleRestart(Duration delay) {
    _restartTimer?.cancel();
    state = state.copyWith(status: VoiceStatus.restarting);
    _restartTimer = Timer(delay, () async {
      if (state.isContinuous && state.status != VoiceStatus.idle) {
        await _beginListeningSession();
      }
    });
  }
}
