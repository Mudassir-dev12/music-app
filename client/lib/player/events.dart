/// In-app event stream for player lifecycle events.
library;

import 'dart:async';

// ---------------------------------------------------------------------------
// PlayerEventType
// ---------------------------------------------------------------------------

enum PlayerEventType {
  trackStarted,
  track30s, // fired after 30 s played or 50% elapsed, whichever comes first
  trackEnded,
}

// ---------------------------------------------------------------------------
// PlayerEvent
// ---------------------------------------------------------------------------

class PlayerEvent {
  const PlayerEvent({
    required this.type,
    required this.videoId,
    required this.timestamp,
  });

  final PlayerEventType type;
  final String videoId;
  final DateTime timestamp;

  @override
  String toString() => 'PlayerEvent(${type.name}, $videoId, $timestamp)';
}

// ---------------------------------------------------------------------------
// Global event stream
// ---------------------------------------------------------------------------

/// Broadcast stream of [PlayerEvent]s emitted by [PlayerController].
///
/// Phase 3 will attach a listener here to persist play history to the backend.
// ignore: close_sinks
final _playerEventController = StreamController<PlayerEvent>.broadcast();

/// The public event stream.  Listen here to react to player lifecycle events.
Stream<PlayerEvent> get playerEvents => _playerEventController.stream;

/// Emits a [PlayerEvent] on the global stream.
///
/// Called only by [PlayerController]; external code should listen, not emit.
void emitPlayerEvent(PlayerEvent event) {
  _playerEventController.add(event);
}
