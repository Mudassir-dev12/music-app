import { fireEvent, render } from '@testing-library/react-native';
import React from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import type { Track } from '@/api/types';
import { QueueContent } from '@/components/QueuePanel';
import { __resetPlayerInternalsForTests, usePlayerStore } from '@/store/player';
import { ThemeProvider } from '@/theme/ThemeProvider';

function makeTrack(id: string, title: string): Track {
  return {
    video_id: id,
    title,
    artists: [{ id: null, name: `Artist ${id}` }],
    artist: `Artist ${id}`,
    album: null,
    album_id: null,
    duration_seconds: 180,
    thumbnail: null,
    is_explicit: false,
  };
}

describe('QueuePanel component', () => {
  beforeEach(() => {
    __resetPlayerInternalsForTests();
    usePlayerStore.getState().resetOnSignOut();
  });

  it('renders Now Playing, Playing Next, and Up Next sections and reorders items', async () => {
    const t1 = makeTrack('q1', 'Current Song');
    const pn1 = makeTrack('pn1', 'Next One');
    const pn2 = makeTrack('pn2', 'Next Two');
    const un1 = makeTrack('un1', 'Up Next Song');

    usePlayerStore.setState({
      queue: [t1, un1],
      currentIndex: 0,
      playNext: [pn1, pn2],
      isPlaying: true,
    });

    const { getByText, getByTestId } = await render(
      <SafeAreaProvider
        initialMetrics={{
          frame: { x: 0, y: 0, width: 390, height: 844 },
          insets: { top: 0, left: 0, right: 0, bottom: 0 },
        }}
      >
        <ThemeProvider>
          <QueueContent />
        </ThemeProvider>
      </SafeAreaProvider>
    );

    expect(getByText('NOW PLAYING')).toBeTruthy();
    expect(getByText('PLAYING NEXT')).toBeTruthy();
    expect(getByText('UP NEXT')).toBeTruthy();
    expect(getByText('Current Song')).toBeTruthy();
    expect(getByText('Next One')).toBeTruthy();
    expect(getByText('Next Two')).toBeTruthy();
    expect(getByText('Up Next Song')).toBeTruthy();

    await fireEvent.press(getByTestId('queue-playnext-0-down'));
    expect(usePlayerStore.getState().playNext.map((t) => t.video_id)).toEqual(['pn2', 'pn1']);
  });
});
