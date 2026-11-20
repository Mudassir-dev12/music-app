import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:melodia/voice/speech_port.dart';

class FakeSpeechRecognizer implements SpeechRecognizerPort {
  bool permissionGranted = true;
  bool available = true;
  bool listening = false;
  List<String> supportedLocales = ['en_US', 'ur_PK'];

  ValueChanged<String>? currentOnResult;
  ValueChanged<VoiceError>? currentOnError;

  int initializeCount = 0;
  int startListeningCount = 0;
  int stopListeningCount = 0;
  int cancelListeningCount = 0;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({String? localeId}) async {
    initializeCount++;
    return available;
  }

  @override
  Future<bool> requestPermission() async {
    return permissionGranted;
  }

  @override
  Future<List<String>> getSupportedLocales() async {
    return List.unmodifiable(supportedLocales);
  }

  @override
  Future<void> startListening({
    required ValueChanged<String> onResult,
    required ValueChanged<VoiceError> onError,
    String? localeId,
    bool continuous = false,
    Duration? pauseFor,
    Duration? listenFor,
  }) async {
    startListeningCount++;
    if (!permissionGranted) {
      onError(const VoiceError(
        kind: VoiceErrorKind.permissionDenied,
        message: 'Microphone permission denied',
        isTransient: false,
      ));
      return;
    }
    if (!available) {
      onError(const VoiceError(
        kind: VoiceErrorKind.notAvailable,
        message: 'Speech recognition not available',
        isTransient: false,
      ));
      return;
    }
    listening = true;
    currentOnResult = onResult;
    currentOnError = onError;
  }

  @override
  Future<void> stopListening() async {
    stopListeningCount++;
    listening = false;
  }

  @override
  Future<void> cancelListening() async {
    cancelListeningCount++;
    listening = false;
  }

  void simulateResult(String words) {
    if (listening && currentOnResult != null) {
      currentOnResult!(words);
    }
  }

  void simulateError(VoiceError error) {
    if (currentOnError != null) {
      currentOnError!(error);
    }
  }
}

class FakeSpeechSynthesizer implements SpeechSynthesizerPort {
  final List<String> spokenTexts = [];
  bool speaking = false;
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  bool autoComplete = true;

  @override
  bool get isSpeaking => speaking;

  @override
  Stream<void> get onCompletion => _completionController.stream;

  @override
  Future<void> speak(
    String text, {
    String? language,
    double volume = 1.0,
    double pitch = 1.0,
    double rate = 0.5,
  }) async {
    spokenTexts.add(text);
    speaking = true;
    if (autoComplete) {
      // Fire completion asynchronously in next microtask
      scheduleMicrotask(() {
        speaking = false;
        if (!_completionController.isClosed) {
          _completionController.add(null);
        }
      });
    }
  }

  void completeManually() {
    speaking = false;
    if (!_completionController.isClosed) {
      _completionController.add(null);
    }
  }

  @override
  Future<void> stop() async {
    speaking = false;
  }

  void dispose() {
    _completionController.close();
  }
}

class FakeAudioRoute implements AudioRoutePort {
  bool connected = false;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isHeadsetOrBluetoothConnected() async => connected;

  @override
  Stream<bool> get onRouteChanged => _controller.stream;

  void setConnected(bool val) {
    connected = val;
    _controller.add(val);
  }

  void dispose() {
    _controller.close();
  }
}
