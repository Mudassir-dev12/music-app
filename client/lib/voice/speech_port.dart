import 'package:flutter/foundation.dart';

enum VoiceErrorKind {
  permissionDenied,
  notAvailable,
  recognitionTimeout,
  networkRequired,
  unknown,
}

class VoiceError {
  const VoiceError({
    required this.kind,
    required this.message,
    this.isTransient = true,
  });

  final VoiceErrorKind kind;
  final String message;
  final bool isTransient;

  @override
  String toString() => 'VoiceError($kind: "$message", isTransient: $isTransient)';
}

/// Abstract port for speech-to-text recognition.
abstract class SpeechRecognizerPort {
  Future<bool> initialize({String? localeId});
  Future<void> startListening({
    required ValueChanged<String> onResult,
    required ValueChanged<VoiceError> onError,
    String? localeId,
    bool continuous = false,
    Duration? pauseFor,
    Duration? listenFor,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  bool get isListening;
  bool get isAvailable;
  Future<bool> requestPermission();
  Future<List<String>> getSupportedLocales();
}

/// Abstract port for text-to-speech output.
abstract class SpeechSynthesizerPort {
  Future<void> speak(
    String text, {
    String? language,
    double volume = 1.0,
    double pitch = 1.0,
    double rate = 0.5,
  });
  Future<void> stop();
  Stream<void> get onCompletion;
  bool get isSpeaking;
}

/// Abstract port for audio output routing detection (Bluetooth / Earbuds vs phone speaker).
abstract class AudioRoutePort {
  Future<bool> isHeadsetOrBluetoothConnected();
  Stream<bool> get onRouteChanged;
}
