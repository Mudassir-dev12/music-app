import 'voice_intent.dart';

/// Prevents the same voice intent from firing twice within a short window
/// (default 2 seconds) when the speech recognizer emits repeated final events.
class CommandDeduper {
  CommandDeduper({this.window = const Duration(seconds: 2)});

  final Duration window;
  VoiceIntent? _lastIntent;
  DateTime? _lastExecutionTime;

  /// Returns true if [intent] should be executed, or false if it is a duplicate within [window].
  bool shouldExecute(VoiceIntent intent, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (_lastIntent == intent && _lastExecutionTime != null) {
      final elapsed = currentTime.difference(_lastExecutionTime!);
      if (elapsed < window) {
        return false;
      }
    }

    _lastIntent = intent;
    _lastExecutionTime = currentTime;
    return true;
  }

  /// Clears the dedup history (e.g. when session ends).
  void reset() {
    _lastIntent = null;
    _lastExecutionTime = null;
  }
}

