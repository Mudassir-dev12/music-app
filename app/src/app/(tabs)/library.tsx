import React from 'react';

import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';

export default function LibraryScreen() {
  return (
    <Screen title="Library" testID="screen-library">
      <EmptyState
        icon="library-outline"
        title="Library Arrives in Phase 3"
        message="Your playlists, liked songs, and play history will live here."
      />
    </Screen>
  );
}
