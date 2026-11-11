export const config = {
  apiUrl: (process.env.EXPO_PUBLIC_API_URL ?? 'http://127.0.0.1:8610').replace(/\/+$/, ''),
  appName: process.env.EXPO_PUBLIC_APP_NAME ?? 'Melodia',
} as const;
