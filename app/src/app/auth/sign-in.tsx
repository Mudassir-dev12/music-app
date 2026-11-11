import { Link } from 'expo-router';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ApiError } from '@/api/client';
import { IconButton } from '@/components/IconButton';
import { config } from '@/lib/config';
import { useSessionStore } from '@/store/session';
import { useTheme } from '@/theme/ThemeProvider';
import { layoutTokens, radii, spacing, typography } from '@/theme/tokens';

export default function SignInScreen() {
  const { colors } = useTheme();
  const { signIn, isAuthenticating } = useSessionStore();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async () => {
    setErrorMessage(null);
    if (!email.trim() || !password) {
      setErrorMessage('Please enter your email and password.');
      return;
    }

    try {
      await signIn(email, password);
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status === 429) {
          const secs = err.retryAfterSec ?? 60;
          setErrorMessage(`Too many attempts, try again in ${secs} s`);
        } else if (err.status === 401) {
          setErrorMessage('Invalid email or password.');
        } else {
          setErrorMessage(err.detail || 'Unable to sign in right now.');
        }
      } else {
        setErrorMessage('Unable to reach server. Please check your connection.');
      }
    }
  };

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: colors.background }]}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.center}
      >
        <View
          style={[
            styles.card,
            { backgroundColor: colors.surface, borderColor: colors.separator },
          ]}
        >
          <View style={styles.header}>
            <Text style={[typography.largeTitle, { color: colors.text }]}>{config.appName}</Text>
            <Text style={[typography.subhead, { color: colors.textSecondary }]}>
              Sign in to listen
            </Text>
          </View>

          <View style={styles.fieldGroup}>
            <Text style={[typography.footnote, { color: colors.textSecondary }]}>Email</Text>
            <TextInput
              value={email}
              onChangeText={setEmail}
              placeholder="you@example.com"
              placeholderTextColor={colors.textTertiary}
              autoCapitalize="none"
              autoComplete="email"
              keyboardType="email-address"
              textContentType="emailAddress"
              returnKeyType="next"
              testID="signin-email"
              accessibilityLabel="Email"
              style={[
                typography.body,
                styles.input,
                {
                  color: colors.text,
                  backgroundColor: colors.surface2,
                  borderColor: colors.separator,
                },
              ]}
            />
          </View>

          <View style={styles.fieldGroup}>
            <Text style={[typography.footnote, { color: colors.textSecondary }]}>Password</Text>
            <View
              style={[
                styles.passwordWrap,
                {
                  backgroundColor: colors.surface2,
                  borderColor: colors.separator,
                },
              ]}
            >
              <TextInput
                value={password}
                onChangeText={setPassword}
                placeholder="Password"
                placeholderTextColor={colors.textTertiary}
                secureTextEntry={!showPassword}
                autoCapitalize="none"
                autoComplete="password"
                textContentType="password"
                returnKeyType="done"
                onSubmitEditing={handleSubmit}
                testID="signin-password"
                accessibilityLabel="Password"
                style={[typography.body, styles.passwordInput, { color: colors.text }]}
              />
              <IconButton
                name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                color={colors.textSecondary}
                onPress={() => setShowPassword((prev) => !prev)}
                accessibilityLabel={showPassword ? 'Hide password' : 'Show password'}
                testID="signin-toggle-password"
              />
            </View>
          </View>

          {errorMessage ? (
            <Text
              style={[typography.footnote, { color: colors.destructive }]}
              accessibilityRole="alert"
              testID="signin-error"
            >
              {errorMessage}
            </Text>
          ) : null}

          <Pressable
            onPress={handleSubmit}
            disabled={isAuthenticating}
            accessibilityRole="button"
            accessibilityLabel="Sign In"
            testID="signin-submit"
            style={({ pressed }) => [
              styles.submitButton,
              {
                backgroundColor: colors.accent,
                opacity: isAuthenticating ? 0.65 : pressed ? 0.85 : 1,
              },
            ]}
          >
            {isAuthenticating ? (
              <ActivityIndicator size="small" color={colors.onAccent} />
            ) : (
              <Text style={[typography.headline, { color: colors.onAccent }]}>Sign In</Text>
            )}
          </Pressable>

          <View style={styles.footer}>
            <Text style={[typography.subhead, { color: colors.textSecondary }]}>
              New here?
            </Text>
            <Link href="/auth/sign-up" asChild>
              <Pressable accessibilityRole="link" testID="goto-signup">
                <Text style={[typography.headline, { color: colors.accent }]}>Create Account</Text>
              </Pressable>
            </Link>
          </View>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.lg,
  },
  card: {
    width: '100%',
    maxWidth: layoutTokens.maxFormWidth,
    borderRadius: radii.sheet,
    borderWidth: layoutTokens.hairline,
    padding: spacing.xl,
    gap: spacing.md,
  },
  header: {
    gap: spacing.xxs,
    marginBottom: spacing.xs,
  },
  fieldGroup: {
    gap: spacing.xs,
  },
  input: {
    borderRadius: radii.card,
    borderWidth: layoutTokens.hairline,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  passwordWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radii.card,
    borderWidth: layoutTokens.hairline,
    paddingLeft: spacing.md,
    paddingRight: spacing.xs,
  },
  passwordInput: {
    flex: 1,
    paddingVertical: spacing.sm,
  },
  submitButton: {
    borderRadius: radii.card,
    paddingVertical: spacing.sm + spacing.xxs,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.xs,
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    marginTop: spacing.xs,
  },
});
