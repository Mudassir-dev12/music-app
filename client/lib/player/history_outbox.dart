/// Offline outbox for play history sync with the backend.
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/errors.dart';
import '../api/user_api.dart';
import '../data/user_data_providers.dart';
import 'events.dart';

/// Cryptographically secure RFC-4122 v4 UUID generator without external dependencies.
String generateUuidV4() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

/// An entry queued for backend history synchronization.
class OutboxItem {
  const OutboxItem({
    required this.videoId,
    required this.listenedSeconds,
    required this.clientEventId,
  });

  final String videoId;
  final int listenedSeconds;
  final String clientEventId;

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'listened_seconds': listenedSeconds,
        'client_event_id': clientEventId,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> json) => OutboxItem(
        videoId: json['video_id'] as String,
        listenedSeconds: json['listened_seconds'] as int,
        clientEventId: json['client_event_id'] as String,
      );
}

/// Provider for the history outbox sync manager.
final historyOutboxProvider = Provider<HistoryOutbox>((ref) {
  final outbox = HistoryOutbox(ref);
  outbox.init();
  return outbox;
});

class HistoryOutbox {
  HistoryOutbox(this.ref);

  final Ref ref;
  static const String _kOutboxKey = 'history_outbox_items';
  static const int _kMaxOutboxItems = 200;

  bool _isFlushing = false;
  bool _needsAnotherFlush = false;

  void init() {
    // Listen to player 30s events
    playerEvents.listen((event) {
      if (event.type == PlayerEventType.track30s) {
        enqueue(event.videoId, 30);
      }
    });

    // Flush on app start
    flush();
  }

  Future<void> enqueue(String videoId, int listenedSeconds) async {
    final eventId = generateUuidV4();
    final item = OutboxItem(
      videoId: videoId,
      listenedSeconds: listenedSeconds,
      clientEventId: eventId,
    );

    final prefs = await SharedPreferences.getInstance();
    final items = await _loadItems(prefs);
    items.add(item);
    // Keep at most 200 items
    while (items.length > _kMaxOutboxItems) {
      items.removeAt(0);
    }
    await _saveItems(prefs, items);

    // Trigger background flush
    await flush();
  }

  Future<void> flush() async {
    if (_isFlushing) {
      _needsAnotherFlush = true;
      return;
    }
    _isFlushing = true;
    try {
      do {
        _needsAnotherFlush = false;
        final prefs = await SharedPreferences.getInstance();
        final items = await _loadItems(prefs);
        if (items.isEmpty) break;

        final api = ref.read(userApiProvider);
        final remaining = List<OutboxItem>.from(items);

        for (final item in items) {
          try {
            await api.recordHistory(
              videoId: item.videoId,
              listenedSeconds: item.listenedSeconds,
              clientEventId: item.clientEventId,
            );
            remaining.removeWhere((e) => e.clientEventId == item.clientEventId);
          } on RateLimitError {
            // Keep item and pause flushing
            break;
          } on ApiError catch (e) {
            // If 4xx other than 429: drop it
            if (e is ValidationError ||
                e is UnauthorizedError ||
                e is ForbiddenError ||
                e is ConflictError) {
              remaining.removeWhere((e) => e.clientEventId == item.clientEventId);
            } else {
              // Server error: keep and pause
              break;
            }
          } catch (_) {
            // Network error: keep and pause
            break;
          }
        }

        await _saveItems(prefs, remaining);
        ref.read(recentProvider.notifier).refresh();
      } while (_needsAnotherFlush);
    } finally {
      _isFlushing = false;
    }
  }

  Future<List<OutboxItem>> _loadItems(SharedPreferences prefs) async {
    final raw = prefs.getString(_kOutboxKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => OutboxItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveItems(
      SharedPreferences prefs, List<OutboxItem> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_kOutboxKey, raw);
  }
}
