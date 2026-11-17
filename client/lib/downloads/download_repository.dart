import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/music_api.dart';
import '../api/user_api.dart';
import '../core/connectivity/connectivity_controller.dart';
import '../core/platform/download_store.dart';
import '../core/platform/network_type.dart';
import 'download_manager.dart';
import 'download_models.dart';

// ---------------------------------------------------------------------------
// Store & Manager Providers
// ---------------------------------------------------------------------------

final downloadStoreProvider = Provider<DownloadStore>((ref) {
  return createDownloadStore();
});

final isDownloadSupportedProvider = Provider<bool>((ref) {
  return ref.watch(downloadStoreProvider).isSupported;
});

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final store = ref.watch(downloadStoreProvider);
  final musicApi = ref.watch(musicApiProvider);
  final apiClient = ref.watch(apiClientProvider);

  final manager = DownloadManager(
    store: store,
    musicApi: musicApi,
    apiClient: apiClient,
    networkDetector: NetworkTypeDetector(),
  );

  // Initialize
  manager.init();

  // Listen to connectivity
  ref.listen<ConnectivityState>(connectivityProvider, (prev, next) {
    manager.onConnectivityChanged(next.isOnline);
  });

  ref.onDispose(() {
    manager.dispose();
  });

  return manager;
});

// ---------------------------------------------------------------------------
// Manifest & Queue Streams
// ---------------------------------------------------------------------------

final downloadManifestProvider = StreamProvider<DownloadManifest>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.manifestStream;
});

final downloadedIdsProvider = Provider<Set<String>>((ref) {
  final manifestAsync = ref.watch(downloadManifestProvider);
  final manifest = manifestAsync.valueOrNull ?? ref.watch(downloadManagerProvider).manifest;
  return manifest.tracks.keys.toSet();
});

final downloadedTracksProvider = Provider<List<ManifestTrack>>((ref) {
  final manifestAsync = ref.watch(downloadManifestProvider);
  final manifest = manifestAsync.valueOrNull ?? ref.watch(downloadManagerProvider).manifest;
  return manifest.tracks.values.toList();
});

final downloadQueueProvider = StreamProvider<List<DownloadItem>>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.queueStream;
});

// ---------------------------------------------------------------------------
// Settings: Wi-Fi Only & Storage Cap
// ---------------------------------------------------------------------------

class WifiOnlyNotifier extends StateNotifier<bool> {
  static const _key = 'melodia_download_wifi_only';
  final SharedPreferences? _prefs;

  WifiOnlyNotifier(this._prefs) : super(_prefs?.getBool(_key) ?? true);

  Future<void> toggle() => set(!state);

  Future<void> set(bool value) async {
    state = value;
    await _prefs?.setBool(_key, value);
  }
}

final wifiOnlyProvider = StateNotifierProvider<WifiOnlyNotifier, bool>((ref) {
  SharedPreferences? prefs;
  try {
    // SharedPreferences may be injected or fetched
  } catch (_) {}
  return WifiOnlyNotifier(prefs);
});

class StorageCapNotifier extends StateNotifier<int> {
  static const _key = 'melodia_download_storage_cap_mb';
  final SharedPreferences? _prefs;

  // Default: 2048 MB (2 GB)
  StorageCapNotifier(this._prefs) : super(_prefs?.getInt(_key) ?? 2048);

  Future<void> setCap(int capMb) async {
    state = capMb;
    await _prefs?.setInt(_key, capMb);
  }
}

final storageCapProvider = StateNotifierProvider<StorageCapNotifier, int>((ref) {
  SharedPreferences? prefs;
  try {
  } catch (_) {}
  return StorageCapNotifier(prefs);
});

// ---------------------------------------------------------------------------
// Limits from Backend
// ---------------------------------------------------------------------------

final downloadLimitsProvider = FutureProvider<DownloadLimits>((ref) async {
  final userApi = ref.watch(userApiProvider);
  return userApi.getDownloadLimits();
});

final totalDownloadBytesUsedProvider = FutureProvider<int>((ref) async {
  final store = ref.watch(downloadStoreProvider);
  return store.totalBytesUsed();
});
