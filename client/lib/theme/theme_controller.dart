import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefsKey = 'theme_mode';

/// 0 = system, 1 = light, 2 = dark
ThemeMode _fromInt(int? v) => switch (v) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

int _toInt(ThemeMode m) => switch (m) {
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
      ThemeMode.system || _ => 0,
    };

class ThemeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _fromInt(prefs.getInt(_kPrefsKey));
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncData<ThemeMode>(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKey, _toInt(mode));
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
