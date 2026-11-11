import type { Track } from '@/api/types';

export type RepeatMode = 'off' | 'all' | 'one';

export type PlaybackStatus =
  | 'idle'
  | 'loading'
  | 'buffering'
  | 'playing'
  | 'paused'
  | 'error';

export type EngineEvent =
  | { type: 'state'; status: PlaybackStatus }
  | { type: 'progress'; positionSec: number; durationSec: number }
  | { type: 'ended' }
  | { type: 'error'; message: string; statusCode?: number }
  | { type: 'remote-next' }
  | { type: 'remote-prev' };

export interface EngineLoadOptions {
  autoplay: boolean;
  startPositionSec?: number;
  url?: string;
}

export interface PlayerEngine {
  load(track: Track, opts: EngineLoadOptions): Promise<void>;
  play(): Promise<void>;
  pause(): Promise<void>;
  seek(seconds: number): Promise<void>;
  setVolume(v: number): void; // 0..1, no-op on native
  onEvent(cb: (e: EngineEvent) => void): () => void;
  destroy(): void;
}

