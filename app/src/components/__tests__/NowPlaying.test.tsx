import { act, render } from '@testing-library/react-native';
import React from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import type { Track } from '@/api/types';
import { NowPlaying } from '@/components/NowPlaying';
import { __resetPlayerInternalsForTests, usePlayerStore } from '@/store/player';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { motion } from '@/theme/tokens';

const TRACK: Track = {
  video_id: 'np123456789',
  title: 'Hero Song',
  artists: [{ id: null, name: 'Hero Artist' }],
  artist: 'Hero Artist',
  album: null,
  album_id: null,
  duration_seconds: 210,
  thumbnail: null,
  is_explicit: false,
};

function renderNowPlaying() {
  return render(
    <SafeAreaProvider
      initialMetrics={{
        frame: { x: 0, y: 0, width: 390, height: 844 },
        insets: { top: 0, left: 0, right: 0, bottom: 0 },
      }}
    >
      <ThemeProvider>
        <NowPlaying />
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

describe('NowPlaying artwork scale', () => {
  beforeEach(() => {
    __resetPlayerInternalsForTests();
    usePlayerStore.getState().resetOnSignOut();
  });

  it('scales artwork between paused (0.86) and playing (1.0)', async () => {
    usePlayerStore.setState({
      queue: [TRACK],
      currentIndex: 0,
      nowPlayingOpen: true,
      isPlaying: false,
    });

    const { getByTestId, rerender } = await renderNowPlaying();
    const artPaused = getByTestId('now-playing-artwork-container');
    const pausedStyle = Array.isArray(artPaused.props.style)
      ? Object.assign({}, ...artPaused.props.style)
      : artPaused.props.style;
    expect(pausedStyle.transform).toEqual([{ scale: motion.artPausedScale }]);

    await act(async () => {
      usePlayerStore.setState({ isPlaying: true });
    });
    await rerender(
      <SafeAreaProvider
        initialMetrics={{
          frame: { x: 0, y: 0, width: 390, height: 844 },
          insets: { top: 0, left: 0, right: 0, bottom: 0 },
        }}
      >
        <ThemeProvider>
          <NowPlaying />
        </ThemeProvider>
      </SafeAreaProvider>
    );

    const artPlaying = getByTestId('now-playing-artwork-container');
    const playingStyle = Array.isArray(artPlaying.props.style)
      ? Object.assign({}, ...artPlaying.props.style)
      : artPlaying.props.style;
    expect(playingStyle.transform).toEqual([{ scale: motion.artPlayingScale }]);
  });
});
