import type { Track } from '@/api/types';

export type PlayerBusEvent =
  | { type: 'track-started'; track: Track }
  | { type: 'track-30s'; track: Track; positionSec: number }
  | { type: 'track-ended'; track: Track };

type Listener = (event: PlayerBusEvent) => void;

class PlayerEventBus {
  private listeners = new Set<Listener>();

  subscribe(cb: Listener): () => void {
    this.listeners.add(cb);
    return () => {
      this.listeners.delete(cb);
    };
  }

  emit(event: PlayerBusEvent): void {
    // Phase 3 attaches server play-history logging to these events.
    for (const cb of this.listeners) {
      try {
        cb(event);
      } catch {
        // Ignore subscriber failures
      }
    }
  }
}

export const playerEvents = new PlayerEventBus();
