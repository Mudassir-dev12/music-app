import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from 'expo-audio';

import type { Track } from '@/api/types';
import type { EngineEvent, EngineLoadOptions, PlayerEngine } from '@/player/types';

class NativePlayerEngine implements PlayerEngine {
  private player: AudioPlayer | null = null;
  private listeners = new Set<(e: EngineEvent) => void>();
  private sub: { remove: () => void } | null = null;
  private modeConfigured = false;
  private currentTrack: Track | null = null;
  private lastProgressMs = 0;

  private emit(event: EngineEvent): void {
    for (const cb of this.listeners) {
      cb(event);
    }
  }

  private async ensureAudioMode(): Promise<void> {
    if (this.modeConfigured) return;
    this.modeConfigured = true;
    try {
      await setAudioModeAsync({
        playsInSilentMode: true,
        shouldPlayInBackground: true,
        interruptionMode: 'doNotMix',
        allowsRecording: false,
        shouldRouteThroughEarpiece: false,
      });
    } catch {
      // Ignore in test environments
    }
  }

  private ensurePlayer(initialUrl?: string): AudioPlayer {
    if (this.player) return this.player;
    const player = createAudioPlayer(initialUrl ?? null, {
      updateInterval: 250,
      keepAudioSessionActive: true,
    });
    this.sub = player.addListener('playbackStatusUpdate', (status) => {
      if (status.error) {
        this.emit({ type: 'error', message: status.error });
        return;
      }

      if (status.didJustFinish) {
        this.emit({ type: 'ended' });
        return;
      }

      if (status.isBuffering) {
        this.emit({ type: 'state', status: 'buffering' });
      } else if (status.playing) {
        this.emit({ type: 'state', status: 'playing' });
      } else if (status.isLoaded) {
        this.emit({ type: 'state', status: 'paused' });
      }

      const now = Date.now();
      if (now - this.lastProgressMs >= 240) {
        this.lastProgressMs = now;
        this.emit({
          type: 'progress',
          positionSec: status.currentTime ?? 0,
          durationSec: status.duration || (this.currentTrack?.duration_seconds ?? 0),
        });
      }
    });
    this.player = player;
    return player;
  }

  async load(track: Track, opts: EngineLoadOptions): Promise<void> {
    this.currentTrack = track;
    await this.ensureAudioMode();
    if (!opts.url) return;

    const player = this.ensurePlayer(opts.url);
    player.replace({ uri: opts.url });

    const metadata = {
      title: track.title,
      artist: track.artist,
      albumTitle: track.album ?? undefined,
      artworkUrl: track.thumbnail ?? undefined,
    };

    try {
      player.setActiveForLockScreen(true, metadata, {
        showNextTrack: true,
        showPreviousTrack: true,
        showSeekForward: true,
        showSeekBackward: true,
      });
      player.updateLockScreenMetadata(metadata);
    } catch {
      // Lock-screen updates may be unavailable in headless tests
    }

    if (opts.startPositionSec && opts.startPositionSec > 0) {
      await player.seekTo(opts.startPositionSec);
    }

    if (opts.autoplay) {
      player.play();
    } else {
      player.pause();
      this.emit({ type: 'state', status: 'paused' });
    }
  }

  async play(): Promise<void> {
    this.player?.play();
  }

  async pause(): Promise<void> {
    this.player?.pause();
  }

  async seek(seconds: number): Promise<void> {
    if (!this.player) return;
    await this.player.seekTo(Math.max(0, seconds));
  }

  setVolume(_v: number): void {
    // Native uses hardware device volume
  }

  onEvent(cb: (e: EngineEvent) => void): () => void {
    this.listeners.add(cb);
    return () => {
      this.listeners.delete(cb);
    };
  }

  destroy(): void {
    this.sub?.remove();
    this.sub = null;
    try {
      this.player?.clearLockScreenControls();
      this.player?.remove();
    } catch {
      // Ignore cleanup errors
    }
    this.player = null;
    this.listeners.clear();
  }
}

export function createPlayerEngine(): PlayerEngine {
  return new NativePlayerEngine();
}

