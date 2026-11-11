import React from 'react';

import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';

export default function BrowseScreen() {
  return (
    <Screen title="Browse" testID="screen-browse">
      <EmptyState
        icon="grid-outline"
        title="Browse Arrives in Phase 4"
        message="Charts, new releases, and curated discovery shelves will live here."
      />
    </Screen>
  );
}

