import { fireEvent, render, waitFor } from '@testing-library/react-native';
import React from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { ApiError } from '@/api/client';
import SignInScreen from '@/app/auth/sign-in';
import { useSessionStore } from '@/store/session';
import { ThemeProvider } from '@/theme/ThemeProvider';

jest.mock('expo-router', () => ({
  Link: ({ children }: { children: React.ReactNode }) => children,
}));

function renderSignIn() {
  return render(
    <SafeAreaProvider
      initialMetrics={{
        frame: { x: 0, y: 0, width: 390, height: 844 },
        insets: { top: 0, left: 0, right: 0, bottom: 0 },
      }}
    >
      <ThemeProvider>
        <SignInScreen />
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

describe('SignInScreen component', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('shows generic error on 401 and Retry-After message on 429', async () => {
    const signInMock = jest
      .fn()
      .mockRejectedValueOnce(new ApiError(401, 'Invalid email or password.'))
      .mockRejectedValueOnce(new ApiError(429, 'Too many attempts', 45));

    useSessionStore.setState({ signIn: signInMock, isAuthenticating: false });

    const { getByTestId, getByText } = await renderSignIn();
    await fireEvent.changeText(getByTestId('signin-email'), 'user@example.com');
    await fireEvent.changeText(getByTestId('signin-password'), 'WrongPass123!');

    await fireEvent.press(getByTestId('signin-submit'));
    await waitFor(() => {
      expect(getByText('Invalid email or password.')).toBeTruthy();
    });

    await fireEvent.press(getByTestId('signin-submit'));
    await waitFor(() => {
      expect(getByText('Too many attempts, try again in 45 s')).toBeTruthy();
    });
  });
});
