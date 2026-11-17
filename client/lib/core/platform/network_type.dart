import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkTypeDetector {
  final Connectivity _connectivity;

  NetworkTypeDetector({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> isNetworkAllowed({required bool wifiOnly}) async {
    if (!wifiOnly) return true;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) return true;
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        return true;
      }
      if (results.contains(ConnectivityResult.none)) {
        return false;
      }
      // On mobile data while wifiOnly is true -> not allowed
      if (results.contains(ConnectivityResult.mobile)) {
        return false;
      }
      return true;
    } catch (_) {
      // If cannot be determined, treat as allowed
      return true;
    }
  }

  Stream<bool> watchNetworkAllowed({required bool wifiOnly}) {
    if (!wifiOnly) {
      return Stream.value(true);
    }
    return _connectivity.onConnectivityChanged.map((results) {
      if (results.isEmpty) return true;
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        return true;
      }
      if (results.contains(ConnectivityResult.none) ||
          results.contains(ConnectivityResult.mobile)) {
        return false;
      }
      return true;
    });
  }
}
