import { create } from 'zustand';

import { api, configureApiTokenBridge } from '@/api/client';
import type { User } from '@/api/types';
import {
  clearStoredRefreshToken,
  getStoredRefreshToken,
  setStoredRefreshToken,
} from '@/store/tokenStorage';

let onSignOutCleanup: (() => void) | null = null;

export function registerSessionCleanup(cb: () => void): void {
  onSignOutCleanup = cb;
}

export interface SessionState {
  user: User | null;
  accessToken: string | null;
  hydrated: boolean;
  isAuthenticating: boolean;
  bootstrap: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (params: {
    email: string;
    password: string;
    displayName?: string;
    inviteCode?: string;
  }) => Promise<void>;
  signOut: () => Promise<void>;
  refreshTokens: () => Promise<string | null>;
  clearLocalSession: () => Promise<void>;
}

export const useSessionStore = create<SessionState>((set, get) => ({
  user: null,
  accessToken: null,
  hydrated: false,
  isAuthenticating: false,

  clearLocalSession: async () => {
    await clearStoredRefreshToken();
    set({ user: null, accessToken: null, hydrated: true });
    onSignOutCleanup?.();
  },

  refreshTokens: async () => {
    const storedRefresh = await getStoredRefreshToken();
    if (!storedRefresh) {
      return null;
    }
    try {
      const res = await api.refresh(storedRefresh);
      await setStoredRefreshToken(res.refresh_token);
      set({ user: res.user, accessToken: res.access_token });
      return res.access_token;
    } catch {
      await get().clearLocalSession();
      return null;
    }
  },

  bootstrap: async () => {
    if (get().hydrated) return;
    const storedRefresh = await getStoredRefreshToken();
    if (!storedRefresh) {
      set({ hydrated: true, user: null, accessToken: null });
      return;
    }
    try {
      const res = await api.refresh(storedRefresh);
      await setStoredRefreshToken(res.refresh_token);
      set({ user: res.user, accessToken: res.access_token, hydrated: true });
    } catch {
      await clearStoredRefreshToken();
      set({ user: null, accessToken: null, hydrated: true });
    }
  },

  signIn: async (email: string, password: string) => {
    set({ isAuthenticating: true });
    try {
      const res = await api.login(email.trim(), password);
      await setStoredRefreshToken(res.refresh_token);
      set({ user: res.user, accessToken: res.access_token, hydrated: true });
    } finally {
      set({ isAuthenticating: false });
    }
  },

  signUp: async ({ email, password, displayName, inviteCode }) => {
    set({ isAuthenticating: true });
    try {
      const payload: {
        email: string;
        password: string;
        display_name?: string;
        invite_code?: string;
      } = {
        email: email.trim(),
        password,
      };
      if (displayName?.trim()) {
        payload.display_name = displayName.trim();
      }
      if (inviteCode?.trim()) {
        payload.invite_code = inviteCode.trim();
      }
      const res = await api.register(payload);
      await setStoredRefreshToken(res.refresh_token);
      set({ user: res.user, accessToken: res.access_token, hydrated: true });
    } finally {
      set({ isAuthenticating: false });
    }
  },

  signOut: async () => {
    const storedRefresh = await getStoredRefreshToken();
    if (storedRefresh) {
      try {
        await api.logout(storedRefresh);
      } catch {
        // Best-effort server logout
      }
    }
    await get().clearLocalSession();
  },
}));

configureApiTokenBridge({
  getAccessToken: () => useSessionStore.getState().accessToken,
  refreshSession: () => useSessionStore.getState().refreshTokens(),
  onAuthFailure: () => {
    void useSessionStore.getState().clearLocalSession();
  },
});

