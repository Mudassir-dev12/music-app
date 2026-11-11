import { Platform } from 'react-native';

export type ThemeMode = 'system' | 'light' | 'dark';
export type ResolvedTheme = 'light' | 'dark';

export interface ThemeColors {
  background: string;
  surface: string;
  surface2: string;
  separator: string;
  text: string;
  textSecondary: string;
  textTertiary: string;
  accent: string;
  destructive: string;
  onAccent: string;
  overlayDark: string;
  overlayMedium: string;
  overlayLight: string;
  blurTint: 'dark' | 'light';
}

export const darkColors: ThemeColors = {
  background: '#000000',
  surface: '#1C1C1E',
  surface2: '#2C2C2E',
  separator: 'rgba(84,84,88,0.65)',
  text: '#FFFFFF',
  textSecondary: 'rgba(235,235,245,0.6)',
  textTertiary: 'rgba(235,235,245,0.3)',
  accent: '#FA233B',
  destructive: '#FF453A',
  onAccent: '#FFFFFF',
  overlayDark: 'rgba(0,0,0,0.72)',
  overlayMedium: 'rgba(0,0,0,0.45)',
  overlayLight: 'rgba(255,255,255,0.12)',
  blurTint: 'dark',
};

export const lightColors: ThemeColors = {
  background: '#FFFFFF',
  surface: '#F2F2F7',
  surface2: '#E5E5EA',
  separator: 'rgba(60,60,67,0.29)',
  text: '#000000',
  textSecondary: 'rgba(60,60,67,0.6)',
  textTertiary: 'rgba(60,60,67,0.3)',
  accent: '#FA2D48',
  destructive: '#FF3B30',
  onAccent: '#FFFFFF',
  overlayDark: 'rgba(0,0,0,0.65)',
  overlayMedium: 'rgba(0,0,0,0.35)',
  overlayLight: 'rgba(0,0,0,0.06)',
  blurTint: 'light',
};

export const fontStack = Platform.select({
  web: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", Inter, Roboto, "Segoe UI", sans-serif',
  default: undefined,
});

export const typography = {
  largeTitle: {
    fontFamily: fontStack,
    fontSize: 34,
    lineHeight: 41,
    fontWeight: '700' as const,
    letterSpacing: -0.4,
  },
  title1: {
    fontFamily: fontStack,
    fontSize: 28,
    lineHeight: 34,
    fontWeight: '700' as const,
    letterSpacing: -0.2,
  },
  title2: {
    fontFamily: fontStack,
    fontSize: 22,
    lineHeight: 28,
    fontWeight: '700' as const,
  },
  title3: {
    fontFamily: fontStack,
    fontSize: 20,
    lineHeight: 25,
    fontWeight: '600' as const,
  },
  headline: {
    fontFamily: fontStack,
    fontSize: 17,
    lineHeight: 22,
    fontWeight: '600' as const,
  },
  body: {
    fontFamily: fontStack,
    fontSize: 17,
    lineHeight: 22,
    fontWeight: '400' as const,
  },
  callout: {
    fontFamily: fontStack,
    fontSize: 16,
    lineHeight: 21,
    fontWeight: '400' as const,
  },
  subhead: {
    fontFamily: fontStack,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '400' as const,
  },
  footnote: {
    fontFamily: fontStack,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '400' as const,
  },
  caption: {
    fontFamily: fontStack,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: '400' as const,
  },
} as const;

export const spacing = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  xxxl: 40,
} as const;

export const radii = {
  artSmall: 6,
  card: 8,
  artHero: 12,
  sheet: 14,
  pill: 9999,
} as const;

export const elevation = {
  artworkShadow: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 24,
    elevation: 12,
  },
} as const;

export const motion = {
  spring: {
    damping: 18,
    stiffness: 180,
  },
  fadeMs: 240,
  crossFadeMs: 300,
  artPausedScale: 0.86,
  artPlayingScale: 1,
} as const;

export const layoutTokens = {
  breakpoints: {
    tablet: 768,
    desktop: 1024,
  },
  pagePadding: {
    phone: spacing.md,
    tablet: spacing.xl,
    desktop: spacing.xxl,
  },
  sidebarWidth: 260,
  playerBarHeight: 76,
  miniPlayerHeight: 58,
  tabBarHeight: 56,
  artMini: 44,
  artRow: 48,
  artCard: 160,
  artHeroMax: 400,
  artHeroMargin: 64,
  playButtonSize: 72,
  iconSizeSm: 16,
  iconSizeMd: 22,
  iconSizeLg: 28,
  iconSizeXl: 44,
  hitSlop: 8,
  hairline: 1,
  progressLineHeight: 2,
  scrubberTrackHeight: 4,
  scrubberTrackActiveHeight: 8,
  scrubberThumbSize: 14,
  grabberWidth: 36,
  grabberHeight: 5,
  maxFormWidth: 420,
  maxModalWidth: 960,
  toastMaxWidth: 440,
  avatarSize: 34,
  badgeOffset: 10,
} as const;

export const zIndices = {
  miniPlayer: 20,
  playerBar: 30,
  overlay: 50,
  modal: 70,
  toast: 100,
} as const;

