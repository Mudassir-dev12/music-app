import { useEffect, useRef } from 'react';
import { Platform } from 'react-native';

import { usePlayerStore } from '@/store/player';

export function useKeyboardShortcuts(enabled: boolean): void {
  const lastNonZeroVolRef = useRef(0.9);

  useEffect(() => {
    if (!enabled || Platform.OS !== 'web' || typeof window === 'undefined') {
      return;
    }

    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.tagName === 'SELECT' ||
          target.isContentEditable)
      ) {
        return;
      }

      const store = usePlayerStore.getState();
      if (store.volume > 0) {
        lastNonZeroVolRef.current = store.volume;
      }

      if (e.code === 'Space') {
        e.preventDefault();
        void store.togglePlayPause();
      } else if (e.code === 'ArrowLeft' && e.shiftKey) {
        e.preventDefault();
        void store.previousTrack();
      } else if (e.code === 'ArrowRight' && e.shiftKey) {
        e.preventDefault();
        void store.nextTrack(false);
      } else if (e.code === 'ArrowLeft') {
        e.preventDefault();
        void store.seek(Math.max(0, store.positionSec - 10));
      } else if (e.code === 'ArrowRight') {
        e.preventDefault();
        void store.seek(Math.min(store.durationSec || Infinity, store.positionSec + 10));
      } else if (e.code === 'ArrowUp') {
        e.preventDefault();
        store.setVolume(Math.min(1, store.volume + 0.05));
      } else if (e.code === 'ArrowDown') {
        e.preventDefault();
        store.setVolume(Math.max(0, store.volume - 0.05));
      } else if (e.key === 'm' || e.key === 'M') {
        e.preventDefault();
        store.setVolume(store.volume > 0 ? 0 : lastNonZeroVolRef.current);
      } else if (e.key === 's' || e.key === 'S') {
        e.preventDefault();
        store.toggleShuffle();
      } else if (e.key === 'r' || e.key === 'R') {
        e.preventDefault();
        store.cycleRepeat();
      } else if (e.key === 'Escape') {
        if (store.queueOpen) store.setQueueOpen(false);
        if (store.nowPlayingOpen) store.setNowPlayingOpen(false);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [enabled]);
}
