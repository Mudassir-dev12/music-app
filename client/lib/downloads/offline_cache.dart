import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/download_store.dart';
import 'download_repository.dart';

class CachedPayload<T> {
  final T data;
  final DateTime updatedAt;
  final bool isOfflineCopy;

  const CachedPayload({
    required this.data,
    required this.updatedAt,
    this.isOfflineCopy = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class OfflineCacheService {
  final DownloadStore _store;

  OfflineCacheService(this._store);

  String _cacheKey(String endpoint, String userId) {
    return 'cache_${userId}_$endpoint';
  }

  Future<void> save<T>({
    required String endpoint,
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    if (!_store.isSupported) return;
    try {
      final payload = {
        'version': 1,
        'userId': userId,
        'endpoint': endpoint,
        'updatedAt': DateTime.now().toIso8601String(),
        'data': data,
      };
      final key = _cacheKey(endpoint, userId);
      await _store.writeOfflineCache(key, jsonEncode(payload));
    } catch (_) {}
  }

  Future<CachedPayload<Map<String, dynamic>>?> load({
    required String endpoint,
    required String userId,
  }) async {
    if (!_store.isSupported) return null;
    try {
      final key = _cacheKey(endpoint, userId);
      final raw = await _store.readOfflineCache(key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['userId'] != userId) return null; // Never show another user's cache

      final updatedAt = DateTime.tryParse(decoded['updatedAt'] as String? ?? '') ?? DateTime.now();
      final data = decoded['data'] as Map<String, dynamic>? ?? {};

      return CachedPayload(
        data: data,
        updatedAt: updatedAt,
        isOfflineCopy: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUserCache(String userId) async {
    if (!_store.isSupported) return;
    await _store.clearOfflineCache();
  }
}

final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  final store = ref.watch(downloadStoreProvider);
  return OfflineCacheService(store);
});

