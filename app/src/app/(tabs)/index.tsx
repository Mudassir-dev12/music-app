import React from 'react';

import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';

export default function ListenNowScreen() {
  return (
    <Screen title="Listen Now" testID="screen-listen-now">
      <EmptyState
        icon="play-circle-outline"
        title="Nothing Played Yet"
        message="Songs you play will appear here under Recently Played."
      />
    </Screen>
  );
}
