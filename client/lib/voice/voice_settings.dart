import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceSettings {
  const VoiceSettings({
    this.rideModeAutoStart = true,
    this.confirmSpoken = true,
    this.aiFallbackEnabled = false,
    this.preferredLanguage = 'auto',
    this.allowSearchWithoutWakeWord = false,
  });

  final bool rideModeAutoStart;
  final bool confirmSpoken;
  final bool aiFallbackEnabled;
  final String preferredLanguage;
  final bool allowSearchWithoutWakeWord;

  VoiceSettings copyWith({
    bool? rideModeAutoStart,
    bool? confirmSpoken,
    bool? aiFallbackEnabled,
    String? preferredLanguage,
    bool? allowSearchWithoutWakeWord,
  }) {
    return VoiceSettings(
      rideModeAutoStart: rideModeAutoStart ?? this.rideModeAutoStart,
      confirmSpoken: confirmSpoken ?? this.confirmSpoken,
      aiFallbackEnabled: aiFallbackEnabled ?? this.aiFallbackEnabled,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      allowSearchWithoutWakeWord:
          allowSearchWithoutWakeWord ?? this.allowSearchWithoutWakeWord,
    );
  }
}

final voiceSettingsProvider =
    NotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
        VoiceSettingsNotifier.new);

class VoiceSettingsNotifier extends Notifier<VoiceSettings> {
  static const _kRideModeAutoStart = 'melodia_voice_ride_mode_auto_start';
  static const _kConfirmSpoken = 'melodia_voice_confirm_spoken';
  static const _kAiFallbackEnabled = 'melodia_voice_ai_fallback';
  static const _kPreferredLanguage = 'melodia_voice_language';
  static const _kAllowSearchNoWake = 'melodia_voice_allow_search_no_wake';

  SharedPreferences? _prefs;

  @override
  VoiceSettings build() {
    _load();
    return const VoiceSettings();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      state = VoiceSettings(
        rideModeAutoStart: _prefs?.getBool(_kRideModeAutoStart) ?? true,
        confirmSpoken: _prefs?.getBool(_kConfirmSpoken) ?? true,
        aiFallbackEnabled: _prefs?.getBool(_kAiFallbackEnabled) ?? false,
        preferredLanguage: _prefs?.getString(_kPreferredLanguage) ?? 'auto',
        allowSearchWithoutWakeWord:
            _prefs?.getBool(_kAllowSearchNoWake) ?? false,
      );
    } catch (_) {}
  }

  Future<void> setRideModeAutoStart(bool value) async {
    state = state.copyWith(rideModeAutoStart: value);
    await _prefs?.setBool(_kRideModeAutoStart, value);
  }

  Future<void> setConfirmSpoken(bool value) async {
    state = state.copyWith(confirmSpoken: value);
    await _prefs?.setBool(_kConfirmSpoken, value);
  }

  Future<void> setAiFallbackEnabled(bool value) async {
    state = state.copyWith(aiFallbackEnabled: value);
    await _prefs?.setBool(_kAiFallbackEnabled, value);
  }

  Future<void> setPreferredLanguage(String value) async {
    state = state.copyWith(preferredLanguage: value);
    await _prefs?.setString(_kPreferredLanguage, value);
  }

  Future<void> setAllowSearchWithoutWakeWord(bool value) async {
    state = state.copyWith(allowSearchWithoutWakeWord: value);
    await _prefs?.setBool(_kAllowSearchNoWake, value);
  }
}
