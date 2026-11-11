import { fireEvent, render } from '@testing-library/react-native';
import React from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import type { Track } from '@/api/types';
import { MiniPlayer } from '@/components/MiniPlayer';
import { __resetPlayerInternalsForTests, usePlayerStore } from '@/store/player';
import { ThemeProvider } from '@/theme/ThemeProvider';

const TRACK: Track = {
  video_id: 'mini1234567',
  title: 'Mini Song',
  artists: [{ id: null, name: 'Mini Artist' }],
  artist: 'Mini Artist',
  album: null,
  album_id: null,
  duration_seconds: 200,
  thumbnail: null,
  is_explicit: false,
};

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <SafeAreaProvider
      initialMetrics={{
        frame: { x: 0, y: 0, width: 390, height: 844 },
        insets: { top: 0, left: 0, right: 0, bottom: 0 },
      }}
    >
      <ThemeProvider>{ui}</ThemeProvider>
    </SafeAreaProvider>
  );
}

describe('MiniPlayer component', () => {
  beforeEach(() => {
    __resetPlayerInternalsForTests();
    usePlayerStore.getState().resetOnSignOut();
  });

  it('is hidden when the queue is empty', async () => {
    const { queryByTestId } = await renderWithProviders(<MiniPlayer />);
    expect(queryByTestId('mini-player')).toBeNull();
  });

  it('shows title/artist and toggles play/pause', async () => {
    const toggleMock = jest.fn(async () => {
      usePlayerStore.setState((s) => ({ isPlaying: !s.isPlaying }));
    });
    usePlayerStore.setState({
      queue: [TRACK],
      currentIndex: 0,
      isPlaying: false,
      togglePlayPause: toggleMock,
    });

    const { getByTestId, getAllByText, getByText } = await renderWithProviders(<MiniPlayer />);
    expect(getByTestId('mini-player')).toBeTruthy();
    expect(getAllByText('Mini Song').length).toBeGreaterThanOrEqual(1);
    expect(getByText('Mini Artist')).toBeTruthy();

    await fireEvent.press(getByTestId('mini-player-play-pause'));
    expect(toggleMock).toHaveBeenCalledTimes(1);
    expect(usePlayerStore.getState().isPlaying).toBe(true);
  });
});
