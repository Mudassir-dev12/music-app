import { useWindowDimensions } from 'react-native';

import { layoutTokens } from '@/theme/tokens';

export type LayoutBreakpoint = 'phone' | 'tablet' | 'desktop';

export interface LayoutInfo {
  width: number;
  height: number;
  breakpoint: LayoutBreakpoint;
  isPhone: boolean;
  isTablet: boolean;
  isDesktop: boolean;
  pagePadding: number;
}

export function getBreakpoint(width: number): LayoutBreakpoint {
  if (width >= layoutTokens.breakpoints.desktop) return 'desktop';
  if (width >= layoutTokens.breakpoints.tablet) return 'tablet';
  return 'phone';
}

export function useLayout(): LayoutInfo {
  const { width, height } = useWindowDimensions();
  const breakpoint = getBreakpoint(width);
  const pagePadding = layoutTokens.pagePadding[breakpoint];

  return {
    width,
    height,
    breakpoint,
    isPhone: breakpoint === 'phone',
    isTablet: breakpoint === 'tablet',
    isDesktop: breakpoint === 'desktop',
    pagePadding,
  };
}
