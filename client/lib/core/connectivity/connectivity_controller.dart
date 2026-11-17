import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart' as config;

enum ConnectivityStatus {
  online,
  reconnecting,
  serverDown,
  noInternet,
}

class ConnectivityState {
  const ConnectivityState({
    required this.status,
    this.latency,
    this.serverVersion,
    this.lastChecked,
    this.lastError,
  });

  final ConnectivityStatus status;
  final Duration? latency;
  final String? serverVersion;
  final DateTime? lastChecked;
  final Object? lastError;

  bool get isOnline => status == ConnectivityStatus.online;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    Duration? latency,
    String? serverVersion,
    DateTime? lastChecked,
    Object? lastError,
    bool clearError = false,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      latency: latency ?? this.latency,
      serverVersion: serverVersion ?? this.serverVersion,
      lastChecked: lastChecked ?? this.lastChecked,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
  ConnectivityController.new,
);

class ConnectivityController extends Notifier<ConnectivityState> {
  Timer? _probeTimer;
  DateTime? _failureStartTime;
  int _backoffIndex = 0;
  bool _isProbing = false;

  static const List<Duration> _backoffDelays = [
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 30),
  ];

  @override
  ConnectivityState build() {
    ref.onDispose(() {
      _probeTimer?.cancel();
    });
    return const ConnectivityState(status: ConnectivityStatus.online);
  }

  /// Reports a network or server failure from an API request.
  void reportFailure({Object? error}) {
    final now = DateTime.now();
    _failureStartTime ??= now;

    // Check if error represents device offline vs server unreachable
    final errStr = error?.toString().toLowerCase() ?? '';
    final isDeviceOffline = errStr.contains('network is unreachable') ||
        errStr.contains('no route to host') ||
        errStr.contains('no address associated with hostname') ||
        errStr.contains('nodename nor servname provided');

    final newStatus = isDeviceOffline
        ? ConnectivityStatus.noInternet
        : (now.difference(_failureStartTime!).inSeconds > 20
            ? ConnectivityStatus.serverDown
            : ConnectivityStatus.reconnecting);

    state = state.copyWith(
      status: newStatus,
      lastError: error,
      lastChecked: now,
    );

    _scheduleNextProbe();
  }

  void _scheduleNextProbe() {
    if (_probeTimer != null && _probeTimer!.isActive) return;

    final delay = _backoffDelays[_backoffIndex];
    if (_backoffIndex < _backoffDelays.length - 1) {
      _backoffIndex++;
    }

    _probeTimer = Timer(delay, () async {
      final success = await probeHealth();
      if (!success) {
        final now = DateTime.now();
        if (_failureStartTime != null &&
            now.difference(_failureStartTime!).inSeconds > 20 &&
            state.status != ConnectivityStatus.noInternet) {
          state = state.copyWith(status: ConnectivityStatus.serverDown);
        }
        _scheduleNextProbe();
      }
    });
  }

  /// Manually triggers an immediate health check / reconnection probe.
  Future<bool> retryNow() async {
    _probeTimer?.cancel();
    _probeTimer = null;
    final success = await probeHealth();
    if (!success) {
      _scheduleNextProbe();
    }
    return success;
  }

  /// Probes GET /health on the configured backend.
  Future<bool> probeHealth() async {
    if (_isProbing) return state.isOnline;
    _isProbing = true;

    final sw = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (_) => true,
      ));

      final uri = Uri.parse(config.apiUrl);
      final healthUrl = uri.replace(path: '/health').toString();

      final resp = await dio.get<dynamic>(healthUrl);
      sw.stop();

      if (resp.statusCode == 200) {
        String? version;
        if (resp.data is Map<String, dynamic>) {
          version = resp.data['version'] as String?;
        }

        _failureStartTime = null;
        _backoffIndex = 0;
        _probeTimer?.cancel();
        _probeTimer = null;

        state = state.copyWith(
          status: ConnectivityStatus.online,
          latency: sw.elapsed,
          serverVersion: version ?? '1.0.0',
          lastChecked: DateTime.now(),
          clearError: true,
        );
        _isProbing = false;
        return true;
      }
    } catch (e) {
      // Probe failed
    } finally {
      _isProbing = false;
    }

    state = state.copyWith(
      lastChecked: DateTime.now(),
    );
    return false;
  }

  @visibleForTesting
  void setFailureStartTimeForTesting(DateTime time) {
    _failureStartTime = time;
  }

  @visibleForTesting
  void setStatusForTesting(ConnectivityStatus status) {
    state = state.copyWith(status: status);
  }
}
