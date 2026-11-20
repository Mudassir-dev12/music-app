import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'speech_port.dart';

class SpeechToTextPluginRecognizer implements SpeechRecognizerPort {
  SpeechToTextPluginRecognizer() : _stt = SpeechToText();

  final SpeechToText _stt;
  bool _isInit = false;

  @override
  bool get isAvailable => _stt.isAvailable;

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<bool> initialize({String? localeId}) async {
    try {
      _isInit = await _stt.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('STT error: ${error.errorMsg} (permanent: ${error.permanent})');
        },
        debugLogging: kDebugMode,
      );
      return _isInit;
    } catch (e) {
      debugPrint('Failed to initialize STT: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_isInit) {
      _isInit = await initialize();
    }
    return _stt.hasPermission;
  }

  @override
  Future<List<String>> getSupportedLocales() async {
    try {
      final list = await _stt.locales();
      return list.map((l) => l.localeId).toList();
    } catch (_) {
      return const ['en_US', 'ur_PK'];
    }
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
    if (!_isInit) {
      final ok = await initialize(localeId: localeId);
      if (!ok) {
        onError(const VoiceError(
          kind: VoiceErrorKind.notAvailable,
          message: 'Speech recognition engine could not be initialized.',
          isTransient: false,
        ));
        return;
      }
    }

    try {
      // ignore: deprecated_member_use
      await _stt.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        // ignore: deprecated_member_use
        localeId: localeId,
        // ignore: deprecated_member_use
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        // ignore: deprecated_member_use
        listenFor: listenFor ?? const Duration(seconds: 30),
        listenOptions: SpeechListenOptions(
          listenMode: continuous ? ListenMode.dictation : ListenMode.confirmation,
          partialResults: false,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      onError(VoiceError(
        kind: VoiceErrorKind.unknown,
        message: e.toString(),
        isTransient: true,
      ));
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      if (_stt.isListening) {
        await _stt.stop();
      }
    } catch (_) {}
  }

  @override
  Future<void> cancelListening() async {
    try {
      if (_stt.isListening) {
        await _stt.cancel();
      }
    } catch (_) {}
  }
}

class FlutterTtsSynthesizer implements SpeechSynthesizerPort {
  FlutterTtsSynthesizer() : _tts = FlutterTts() {
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      if (!_completionController.isClosed) {
        _completionController.add(null);
      }
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _tts.setErrorHandler((dynamic msg) {
      _isSpeaking = false;
      debugPrint('TTS error: $msg');
    });
  }

  final FlutterTts _tts;
  bool _isSpeaking = false;
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

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
    try {
      _isSpeaking = true;
      if (language != null) {
        await _tts.setLanguage(language);
      }
      await _tts.setVolume(volume.clamp(0.0, 1.0));
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
      await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('TTS speak failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }
}

class AudioRoutePlugin implements AudioRoutePort {
  AudioRoutePlugin() {
    if (!kIsWeb) {
      _init();
    }
  }

  AudioSession? _session;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<Set<AudioDevice>>? _sub;

  Future<void> _init() async {
    try {
      _session = await AudioSession.instance;
      _sub = _session?.devicesStream.listen((devices) {
        final isConnected = _checkDevices(devices);
        _controller.add(isConnected);
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  bool _checkDevices(Iterable<AudioDevice> devices) {
    for (final d in devices) {
      // ignore: experimental_member_use
      if (d.type == AudioDeviceType.bluetoothA2dp ||
          // ignore: experimental_member_use
          d.type == AudioDeviceType.bluetoothSco ||
          // ignore: experimental_member_use
          d.type == AudioDeviceType.bluetoothLe ||
          // ignore: experimental_member_use
          d.type == AudioDeviceType.wiredHeadset ||
          // ignore: experimental_member_use
          d.type == AudioDeviceType.wiredHeadphones) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> isHeadsetOrBluetoothConnected() async {
    if (kIsWeb) return false;
    try {
      _session ??= await AudioSession.instance;
      final devices = await _session!.getDevices();
      return _checkDevices(devices);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onRouteChanged => _controller.stream;

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
