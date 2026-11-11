import AsyncStorage from '@react-native-async-storage/async-storage';
import * as RN from 'react-native';
import { act, renderHook } from '@testing-library/react-native';

import { api } from '@/api/client';
import type { Track } from '@/api/types';
import { getCurrentTrack } from '@/player/queue';
import type { EngineEvent, PlayerEngine } from '@/player/types';
import { __resetPlayerInternalsForTests, usePlayerStore } from '@/store/player';
import { useToastStore } from '@/store/toast';
import { getBreakpoint, useLayout } from '@/hooks/useLayout';
import { useDebounce } from '@/hooks/useDebounce';

import * as playerImpl from '@/player/player';

let mockLatestEngine: jest.Mocked<PlayerEngine>;
let listener: ((e: EngineEvent) => void) | null = null;

jest.mock('@/player/player', () => ({
  createPlayerEngine: jest.fn(),
}));

function makeTrack(id: string): Track {
  return {
    video_id: id,
    title: `Track ${id}`,
    artists: [{ id: null, name: 'Tester' }],
    artist: 'Tester',
    album: null,
    album_id: null,
    duration_seconds: 180,
    thumbnail: null,
    is_explicit: false,
  };
}

describe('player store recovery and persistence', () => {
  beforeEach(() => {
    __resetPlayerInternalsForTests();
    usePlayerStore.getState().resetOnSignOut();
    usePlayerStore.setState({ hydrated: false });
    useToastStore.getState().hide();

    mockLatestEngine = {
      load: jest.fn(async () => {}),
      play: jest.fn(async () => {}),
      pause: jest.fn(async () => {}),
      seek: jest.fn(async () => {}),
      setVolume: jest.fn(),
      onEvent: jest.fn((cb) => {
        listener = cb;
        return () => {
          listener = null;
        };
      }),
      destroy: jest.fn(),
    } as unknown as jest.Mocked<PlayerEngine>;

    (playerImpl.createPlayerEngine as jest.Mock).mockReturnValue(mockLatestEngine);

    jest.spyOn(api, 'createAudioTicket').mockImplementation(async (vid) => ({
      url: `/audio/${vid}?t=ticket-${Math.random()}`,
      expires_in: 7200,
    }));
  });

  afterEach(() => {
    __resetPlayerInternalsForTests();
    jest.restoreAllMocks();
  });

  it('recovers once on error, skips on second failure, and stops after three consecutive failures', async () => {
    const tracks = [makeTrack('vid00000001'), makeTrack('vid00000002'), makeTrack('vid00000003')];
    await usePlayerStore.getState().playTracks(tracks, 0, 'Test');

    expect(getCurrentTrack(usePlayerStore.getState())?.video_id).toBe('vid00000001');
    usePlayerStore.setState({ positionSec: 42 });

    // Error #1 on track 1 -> refreshes ticket and resumes at 42s
    await act(async () => {
      listener?.({ type: 'error', message: 'Expired' });
      await Promise.resolve();
    });
    expect(getCurrentTrack(usePlayerStore.getState())?.video_id).toBe('vid00000001');
    expect(mockLatestEngine.load).toHaveBeenLastCalledWith(
      tracks[0],
      expect.objectContaining({ startPositionSec: 42, autoplay: true })
    );

    // Error #2 on track 1 -> toast & skips to track 2
    await act(async () => {
      listener?.({ type: 'error', message: 'Still broken' });
      await Promise.resolve();
    });
    expect(useToastStore.getState().current?.message).toBe('This song is unavailable');
    expect(getCurrentTrack(usePlayerStore.getState())?.video_id).toBe('vid00000002');
    expect(usePlayerStore.getState().consecutiveErrors).toBe(1);

    // Fail track 2 twice -> skips to track 3 (consecutiveErrors = 2)
    await act(async () => {
      listener?.({ type: 'error', message: 'Fail 2a' });
      await Promise.resolve();
    });
    await act(async () => {
      listener?.({ type: 'error', message: 'Fail 2b' });
      await Promise.resolve();
    });
    expect(getCurrentTrack(usePlayerStore.getState())?.video_id).toBe('vid00000003');
    expect(usePlayerStore.getState().consecutiveErrors).toBe(2);

    // Fail track 3 twice -> consecutiveErrors reaches 3 -> stops playback
    await act(async () => {
      listener?.({ type: 'error', message: 'Fail 3a' });
      await Promise.resolve();
    });
    await act(async () => {
      listener?.({ type: 'error', message: 'Fail 3b' });
      await Promise.resolve();
    });
    expect(usePlayerStore.getState().consecutiveErrors).toBe(3);
    expect(usePlayerStore.getState().status).toBe('error');
    expect(usePlayerStore.getState().isPlaying).toBe(false);
  });

  it('restores persisted state paused with saved position', async () => {
    const t1 = makeTrack('persist0001');
    await AsyncStorage.setItem(
      'melodia.player_state',
      JSON.stringify({
        queue: [t1],
        originalQueue: [],
        currentIndex: 0,
        activeOverride: null,
        playNext: [],
        shuffle: false,
        repeat: 'all',
        volume: 0.5,
        positionSec: 77,
        sourceLabel: 'Search',
        recentlyPlayed: [t1],
      })
    );

    await usePlayerStore.getState().restore();
    const s = usePlayerStore.getState();
    expect(s.hydrated).toBe(true);
    expect(s.isPlaying).toBe(false);
    expect(s.status).toBe('paused');
    expect(s.positionSec).toBe(77);
    expect(s.repeat).toBe('all');
    expect(getCurrentTrack(s)?.video_id).toBe('persist0001');
  });
});

describe('useLayout breakpoints and useDebounce', () => {
  it('computes breakpoints accurately', async () => {
    expect(getBreakpoint(390)).toBe('phone');
    expect(getBreakpoint(768)).toBe('tablet');
    expect(getBreakpoint(1023)).toBe('tablet');
    expect(getBreakpoint(1024)).toBe('desktop');

    const { result } = await renderHook(() => useLayout());
    await act(async () => {
      RN.Dimensions.set({
        window: { width: 1280, height: 800, scale: 1, fontScale: 1 },
        screen: { width: 1280, height: 800, scale: 1, fontScale: 1 },
      });
    });
    expect(result.current.isDesktop).toBe(true);
    expect(result.current.pagePadding).toBe(32);
  });

  it('debounces values by delayMs', async () => {
    jest.useFakeTimers();
    const { result, rerender } = await renderHook(
      ({ q }: { q: string }) => useDebounce(q, 300),
      { initialProps: { q: '' } }
    );
    expect(result.current).toBe('');
    await rerender({ q: 'believer' });
    expect(result.current).toBe('');

    await act(async () => {
      jest.advanceTimersByTime(299);
    });
    expect(result.current).toBe('');

    await act(async () => {
      jest.advanceTimersByTime(1);
    });
    expect(result.current).toBe('believer');
    jest.useRealTimers();
  });
});
