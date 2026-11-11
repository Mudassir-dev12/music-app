import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { AccessibilityInfo, useColorScheme } from 'react-native';

import {
  darkColors,
  lightColors,
  type ResolvedTheme,
  type ThemeColors,
  type ThemeMode,
} from './tokens';

const THEME_STORAGE_KEY = 'melodia.theme_mode';

export interface ThemeContextValue {
  mode: ThemeMode;
  resolved: ResolvedTheme;
  colors: ThemeColors;
  reduceMotion: boolean;
  setMode: (mode: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  mode: 'system',
  resolved: 'dark',
  colors: darkColors,
  reduceMotion: false,
  setMode: () => {},
});

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const systemScheme = useColorScheme();
  const [mode, setModeState] = useState<ThemeMode>('system');
  const [reduceMotion, setReduceMotion] = useState(false);

  useEffect(() => {
    let active = true;
    AsyncStorage.getItem(THEME_STORAGE_KEY)
      .then((saved) => {
        if (!active) return;
        if (saved === 'light' || saved === 'dark' || saved === 'system') {
          setModeState(saved);
        }
      })
      .catch(() => {});

    AccessibilityInfo.isReduceMotionEnabled()
      .then((enabled) => {
        if (active) setReduceMotion(Boolean(enabled));
      })
      .catch(() => {});

    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', (enabled) => {
      setReduceMotion(Boolean(enabled));
    });

    return () => {
      active = false;
      sub.remove();
    };
  }, []);

  const setMode = useCallback((next: ThemeMode) => {
    setModeState(next);
    AsyncStorage.setItem(THEME_STORAGE_KEY, next).catch(() => {});
  }, []);

  const resolved: ResolvedTheme = useMemo(() => {
    if (mode === 'light' || mode === 'dark') {
      return mode;
    }
    return systemScheme === 'light' ? 'light' : 'dark';
  }, [mode, systemScheme]);

  const colors = resolved === 'light' ? lightColors : darkColors;

  const value = useMemo<ThemeContextValue>(
    () => ({ mode, resolved, colors, reduceMotion, setMode }),
    [mode, resolved, colors, reduceMotion, setMode]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  return useContext(ThemeContext);
}

