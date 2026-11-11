import type { Track } from '@/api/types';
import type { EngineEvent, EngineLoadOptions, PlayerEngine } from '@/player/types';

class WebPlayerEngine implements PlayerEngine {
  private audio: HTMLAudioElement | null = null;
  private listeners = new Set<(e: EngineEvent) => void>();
  private lastProgressMs = 0;
  private currentTrack: Track | null = null;
  private pendingSeekSec: number | null = null;

  constructor() {
    if (typeof window !== 'undefined' && typeof Audio !== 'undefined') {
      this.audio = new Audio();
      this.audio.preload = 'auto';
      this.bindAudioEvents(this.audio);
      this.bindMediaSession();
    }
  }

  private emit(event: EngineEvent): void {
    for (const cb of this.listeners) {
      cb(event);
    }
  }

  private bindAudioEvents(audio: HTMLAudioElement): void {
    audio.addEventListener('loadstart', () => {
      this.emit({ type: 'state', status: 'loading' });
    });

    audio.addEventListener('waiting', () => {
      this.emit({ type: 'state', status: 'buffering' });
    });

    audio.addEventListener('loadedmetadata', () => {
      if (this.pendingSeekSec !== null && this.pendingSeekSec > 0) {
        try {
          audio.currentTime = this.pendingSeekSec;
        } catch {
          // Ignore seek errors before ready
        }
        this.pendingSeekSec = null;
      }
      this.emitProgress(true);
    });

    audio.addEventListener('playing', () => {
      this.emit({ type: 'state', status: 'playing' });
      this.updateMediaSessionState('playing');
    });

    audio.addEventListener('pause', () => {
      if (!audio.ended) {
        this.emit({ type: 'state', status: 'paused' });
        this.updateMediaSessionState('paused');
      }
    });

    audio.addEventListener('timeupdate', () => {
      this.emitProgress(false);
    });

    audio.addEventListener('ended', () => {
      this.emitProgress(true);
      this.emit({ type: 'ended' });
    });

    audio.addEventListener('error', () => {
      const code = audio.error?.code;
      const msg =
        code === MediaError.MEDIA_ERR_NETWORK
          ? 'Network error while streaming audio.'
          : 'Audio playback error.';
      this.emit({ type: 'error', message: msg });
    });
  }

  private emitProgress(force: boolean): void {
    if (!this.audio) return;
    const now = Date.now();
    if (!force && now - this.lastProgressMs < 250) {
      return;
    }
    this.lastProgressMs = now;
    const positionSec = Number.isFinite(this.audio.currentTime) ? this.audio.currentTime : 0;
    const durationSec = Number.isFinite(this.audio.duration)
      ? this.audio.duration
      : (this.currentTrack?.duration_seconds ?? 0);

    this.emit({ type: 'progress', positionSec, durationSec });
    this.updateMediaSessionPosition(positionSec, durationSec);
  }

  private bindMediaSession(): void {
    if (typeof navigator === 'undefined' || !('mediaSession' in navigator)) return;
    const ms = navigator.mediaSession;
    const safeHandle = (action: MediaSessionAction, handler: MediaSessionActionHandler) => {
      try {
        ms.setActionHandler(action, handler);
      } catch {
        // Unsupported action in this browser
      }
    };

    safeHandle('play', () => {
      void this.play();
    });
    safeHandle('pause', () => {
      void this.pause();
    });
    safeHandle('previoustrack', () => {
      this.emit({ type: 'remote-prev' });
    });
    safeHandle('nexttrack', () => {
      this.emit({ type: 'remote-next' });
    });
    safeHandle('seekto', (details) => {
      if (typeof details.seekTime === 'number') {
        void this.seek(details.seekTime);
      }
    });
    safeHandle('seekbackward', (details) => {
      if (this.audio) {
        const offset = details.seekOffset ?? 10;
        void this.seek(Math.max(0, this.audio.currentTime - offset));
      }
    });
    safeHandle('seekforward', (details) => {
      if (this.audio) {
        const offset = details.seekOffset ?? 10;
        const dur = Number.isFinite(this.audio.duration) ? this.audio.duration : Infinity;
        void this.seek(Math.min(dur, this.audio.currentTime + offset));
      }
    });
  }

  private updateMediaSessionMetadata(track: Track): void {
    if (
      typeof navigator === 'undefined' ||
      !('mediaSession' in navigator) ||
      typeof MediaMetadata === 'undefined'
    ) {
      return;
    }
    navigator.mediaSession.metadata = new MediaMetadata({
      title: track.title,
      artist: track.artist,
      album: track.album ?? '',
      artwork: track.thumbnail
        ? [{ src: track.thumbnail, sizes: '544x544', type: 'image/jpeg' }]
        : [],
    });
  }

  private updateMediaSessionState(state: MediaSessionPlaybackState): void {
    if (typeof navigator === 'undefined' || !('mediaSession' in navigator)) return;
    navigator.mediaSession.playbackState = state;
  }

  private updateMediaSessionPosition(position: number, duration: number): void {
    if (
      typeof navigator === 'undefined' ||
      !('mediaSession' in navigator) ||
      typeof navigator.mediaSession.setPositionState !== 'function'
    ) {
      return;
    }
    if (!Number.isFinite(duration) || duration <= 0) return;
    try {
      navigator.mediaSession.setPositionState({
        duration,
        playbackRate: 1,
        position: Math.min(duration, Math.max(0, position)),
      });
    } catch {
      // Ignore invalid position states
    }
  }

  async load(track: Track, opts: EngineLoadOptions): Promise<void> {
    this.currentTrack = track;
    this.updateMediaSessionMetadata(track);
    if (!this.audio || !opts.url) return;

    this.pendingSeekSec = opts.startPositionSec ?? null;
    this.audio.src = opts.url;
    this.audio.load();

    if (opts.autoplay) {
      await this.play();
    } else {
      this.emit({ type: 'state', status: 'paused' });
    }
  }

  async play(): Promise<void> {
    if (!this.audio) return;
    try {
      await this.audio.play();
    } catch (err) {
      const name = err instanceof Error ? err.name : '';
      if (name === 'NotAllowedError') {
        this.emit({ type: 'state', status: 'paused' });
        return;
      }
      this.emit({
        type: 'error',
        message: err instanceof Error ? err.message : 'Unable to start audio playback.',
      });
    }
  }

  async pause(): Promise<void> {
    if (!this.audio) return;
    this.audio.pause();
  }

  async seek(seconds: number): Promise<void> {
    if (!this.audio) return;
    const clamped = Math.max(0, seconds);
    try {
      this.audio.currentTime = clamped;
      this.emitProgress(true);
    } catch {
      this.pendingSeekSec = clamped;
    }
  }

  setVolume(v: number): void {
    if (!this.audio) return;
    this.audio.volume = Math.min(1, Math.max(0, v));
  }

  onEvent(cb: (e: EngineEvent) => void): () => void {
    this.listeners.add(cb);
    return () => {
      this.listeners.delete(cb);
    };
  }

  destroy(): void {
    if (this.audio) {
      this.audio.pause();
      this.audio.src = '';
      this.audio = null;
    }
    this.listeners.clear();
  }
}

export function createPlayerEngine(): PlayerEngine {
  return new WebPlayerEngine();
}

