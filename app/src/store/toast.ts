import { create } from 'zustand';

export type ToastTone = 'info' | 'error' | 'success';

export interface ToastItem {
  id: number;
  message: string;
  tone: ToastTone;
}

interface ToastState {
  current: ToastItem | null;
  show: (message: string, tone?: ToastTone, durationMs?: number) => void;
  hide: () => void;
}

let timerId: ReturnType<typeof setTimeout> | null = null;
let seq = 0;

export const useToastStore = create<ToastState>((set) => ({
  current: null,
  show: (message, tone = 'info', durationMs = 3500) => {
    if (timerId) {
      clearTimeout(timerId);
      timerId = null;
    }
    const id = ++seq;
    set({ current: { id, message, tone } });
    timerId = setTimeout(() => {
      set((state) => (state.current?.id === id ? { current: null } : state));
      timerId = null;
    }, durationMs);
  },
  hide: () => {
    if (timerId) {
      clearTimeout(timerId);
      timerId = null;
    }
    set({ current: null });
  },
}));
