import React from 'react';
import { FlatList, type ListRenderItem, StyleSheet } from 'react-native';

import { spacing } from '@/theme/tokens';

export interface CarouselProps<T> {
  data: T[];
  keyExtractor: (item: T, index: number) => string;
  renderItem: ListRenderItem<T>;
  snapInterval?: number;
  testID?: string;
}

export function Carousel<T>({
  data,
  keyExtractor,
  renderItem,
  snapInterval,
  testID,
}: CarouselProps<T>) {
  return (
    <FlatList
      horizontal
      data={data}
      keyExtractor={keyExtractor}
      renderItem={renderItem}
      showsHorizontalScrollIndicator={false}
      snapToInterval={snapInterval}
      decelerationRate="fast"
      contentContainerStyle={styles.content}
      testID={testID}
    />
  );
}

const styles = StyleSheet.create({
  content: {
    gap: spacing.md,
  },
});

