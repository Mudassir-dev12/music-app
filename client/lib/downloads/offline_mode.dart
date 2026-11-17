import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/connectivity/connectivity_controller.dart';

class OfflineModeState {
  final bool isOffline;
  final bool isManual;
  final bool isAuto;

  const OfflineModeState({
    required this.isOffline,
    this.isManual = false,
    this.isAuto = false,
  });

  OfflineModeState copyWith({
    bool? isOffline,
    bool? isManual,
    bool? isAuto,
  }) {
    return OfflineModeState(
      isOffline: isOffline ?? this.isOffline,
      isManual: isManual ?? this.isManual,
      isAuto: isAuto ?? this.isAuto,
    );
  }
}

class OfflineModeNotifier extends StateNotifier<OfflineModeState> {
  static const _kManualKey = 'melodia_manual_offline_mode';
  final SharedPreferences? _prefs;
  Timer? _autoOfflineTimer;

  OfflineModeNotifier(this._prefs)
      : super(OfflineModeState(
          isOffline: _prefs?.getBool(_kManualKey) ?? false,
          isManual: _prefs?.getBool(_kManualKey) ?? false,
          isAuto: false,
        ));

  void setManualOffline(bool value) {
    _prefs?.setBool(_kManualKey, value);
    if (value) {
      state = const OfflineModeState(isOffline: true, isManual: true, isAuto: false);
    } else {
      // Revert manual: if auto is still triggered, remain auto-offline
      state = OfflineModeState(isOffline: state.isAuto, isManual: false, isAuto: state.isAuto);
    }
  }

  void toggleManualOffline() {
    setManualOffline(!state.isManual);
  }

  void onConnectivityStateChanged(ConnectivityState connectivity) {
    if (state.isManual) {
      // Manual offline takes precedence over auto changes
      return;
    }

    if (!connectivity.isOnline) {
      // Start 15s timer for auto-offline
      _autoOfflineTimer ??= Timer(const Duration(seconds: 15), () {
        if (!state.isManual) {
          state = const OfflineModeState(isOffline: true, isManual: false, isAuto: true);
        }
      });
    } else {
      _autoOfflineTimer?.cancel();
      _autoOfflineTimer = null;
      if (state.isAuto) {
        state = const OfflineModeState(isOffline: false, isManual: false, isAuto: false);
      }
    }
  }

  @override
  void dispose() {
    _autoOfflineTimer?.cancel();
    super.dispose();
  }
}

final offlineModeProvider =
    StateNotifierProvider<OfflineModeNotifier, OfflineModeState>((ref) {
  SharedPreferences? prefs;
  try {} catch (_) {}
  final notifier = OfflineModeNotifier(prefs);

  ref.listen<ConnectivityState>(connectivityProvider, (prev, next) {
    notifier.onConnectivityStateChanged(next);
  });

  return notifier;
});

final offlineModeControllerProvider = offlineModeProvider;

final isOfflineModeProvider = Provider<bool>((ref) {
  return ref.watch(offlineModeProvider).isOffline;
});
