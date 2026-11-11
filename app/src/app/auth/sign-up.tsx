import { Link } from 'expo-router';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
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

export default function SignUpScreen() {
  const { colors } = useTheme();
  const { signUp, isAuthenticating } = useSessionStore();

  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [password, setPassword] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [inviteRequired, setInviteRequired] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  const handleSubmit = async () => {
    setErrorMessage(null);
    setFieldErrors({});

    if (!email.trim()) {
      setFieldErrors({ email: 'Email is required.' });
      return;
    }
    if (password.length < 10) {
      setFieldErrors({ password: 'Password must be at least 10 characters.' });
      return;
    }

    try {
      await signUp({
        email,
        password,
        displayName,
        inviteCode,
      });
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status === 429) {
          const secs = err.retryAfterSec ?? 60;
          setErrorMessage(`Too many attempts, try again in ${secs} s`);
        } else if (err.status === 403 && err.detail.toLowerCase().includes('invite')) {
          setInviteRequired(true);
          setErrorMessage('An invite code is required to register on this server.');
        } else if (err.status === 422) {
          setFieldErrors(err.fieldErrors);
          setErrorMessage(err.detail);
        } else {
          setErrorMessage(err.detail || 'Unable to create account.');
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
        style={styles.flex}
      >
        <ScrollView
          contentContainerStyle={styles.center}
          keyboardShouldPersistTaps="handled"
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
                Create your account
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
                testID="signup-email"
                accessibilityLabel="Email"
                style={[
                  typography.body,
                  styles.input,
                  {
                    color: colors.text,
                    backgroundColor: colors.surface2,
                    borderColor: fieldErrors.email ? colors.destructive : colors.separator,
                  },
                ]}
              />
              {fieldErrors.email ? (
                <Text style={[typography.caption, { color: colors.destructive }]}>
                  {fieldErrors.email}
                </Text>
              ) : null}
            </View>

            <View style={styles.fieldGroup}>
              <Text style={[typography.footnote, { color: colors.textSecondary }]}>
                Display Name (optional)
              </Text>
              <TextInput
                value={displayName}
                onChangeText={setDisplayName}
                placeholder="Alex"
                placeholderTextColor={colors.textTertiary}
                testID="signup-display-name"
                accessibilityLabel="Display Name"
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
              <Text style={[typography.footnote, { color: colors.textSecondary }]}>
                Password (10+ characters)
              </Text>
              <View
                style={[
                  styles.passwordWrap,
                  {
                    backgroundColor: colors.surface2,
                    borderColor: fieldErrors.password ? colors.destructive : colors.separator,
                  },
                ]}
              >
                <TextInput
                  value={password}
                  onChangeText={setPassword}
                  placeholder="At least 10 characters"
                  placeholderTextColor={colors.textTertiary}
                  secureTextEntry={!showPassword}
                  autoCapitalize="none"
                  textContentType="newPassword"
                  testID="signup-password"
                  accessibilityLabel="Password"
                  style={[typography.body, styles.passwordInput, { color: colors.text }]}
                />
                <IconButton
                  name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                  color={colors.textSecondary}
                  onPress={() => setShowPassword((prev) => !prev)}
                  accessibilityLabel={showPassword ? 'Hide password' : 'Show password'}
                />
              </View>
              {fieldErrors.password ? (
                <Text style={[typography.caption, { color: colors.destructive }]}>
                  {fieldErrors.password}
                </Text>
              ) : null}
            </View>

            <View style={styles.fieldGroup}>
              <Text style={[typography.footnote, { color: colors.textSecondary }]}>
                {inviteRequired ? 'Invite Code (required)' : 'Invite Code (optional)'}
              </Text>
              <TextInput
                value={inviteCode}
                onChangeText={setInviteCode}
                placeholder="Server invite code"
                placeholderTextColor={colors.textTertiary}
                autoCapitalize="none"
                testID="signup-invite-code"
                accessibilityLabel="Invite Code"
                style={[
                  typography.body,
                  styles.input,
                  {
                    color: colors.text,
                    backgroundColor: colors.surface2,
                    borderColor: inviteRequired ? colors.accent : colors.separator,
                  },
                ]}
              />
            </View>

            {errorMessage ? (
              <Text
                style={[typography.footnote, { color: colors.destructive }]}
                accessibilityRole="alert"
                testID="signup-error"
              >
                {errorMessage}
              </Text>
            ) : null}

            <Pressable
              onPress={handleSubmit}
              disabled={isAuthenticating}
              accessibilityRole="button"
              accessibilityLabel="Create Account"
              testID="signup-submit"
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
                <Text style={[typography.headline, { color: colors.onAccent }]}>
                  Create Account
                </Text>
              )}
            </Pressable>

            <View style={styles.footer}>
              <Text style={[typography.subhead, { color: colors.textSecondary }]}>
                Already have an account?
              </Text>
              <Link href="/auth/sign-in" asChild>
                <Pressable accessibilityRole="link" testID="goto-signin">
                  <Text style={[typography.headline, { color: colors.accent }]}>Sign In</Text>
                </Pressable>
              </Link>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  center: {
    flexGrow: 1,
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
