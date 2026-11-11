import React from 'react';

import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';

export default function SearchScreen() {
  return (
    <Screen title="Search" testID="screen-search">
      <EmptyState
        icon="search-outline"
        title="Search for Songs"
        message="Find tracks to play from the catalog."
      />
    </Screen>
  );
}
