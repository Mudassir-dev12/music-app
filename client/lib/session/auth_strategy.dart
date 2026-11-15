import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/auth_api.dart';
import '../api/errors.dart';
import 'session_controller.dart';
import 'token_store.dart';

/// Strategy abstraction for authentication across phases.
///
/// In Phase 3-7: [SilentAuthStrategy] signs in silently as a built-in account.
/// In Phase 8: [AccountAuthStrategy] with real sign-in/sign-up screens will replace it.
abstract class AuthStrategy {
  Future<void> ensureSignedIn();
  bool get needsUi;
  Future<void> signOut();
}

/// The active authentication strategy.
final authStrategyProvider = Provider<AuthStrategy>((ref) {
  return SilentAuthStrategy(ref);
});

/// Silent sign-in strategy for personal use and build phases.
///
/// Credentials come from `--dart-define` (or `dart_defines.json`).
class SilentAuthStrategy implements AuthStrategy {
  SilentAuthStrategy(this.ref);

  final Ref ref;

  static const String localEmail =
      String.fromEnvironment('LOCAL_EMAIL', defaultValue: 'test@example.com');
  static const String localPassword =
      String.fromEnvironment('LOCAL_PASSWORD', defaultValue: 'Password12345!');
  static const String localInviteCode =
      String.fromEnvironment('LOCAL_INVITE_CODE', defaultValue: '');
  static const bool allowSilentInRelease =
      bool.fromEnvironment('ALLOW_SILENT_LOGIN_IN_RELEASE', defaultValue: false);

  @override
  bool get needsUi => false;

  @override
  Future<void> ensureSignedIn() async {
    // Safety guard: refuse to run in release builds unless explicitly opted-in
    if (kReleaseMode && !allowSilentInRelease) {
      throw StateError(
        'SilentAuthStrategy refuses to run in release mode without '
        '--dart-define=ALLOW_SILENT_LOGIN_IN_RELEASE=true.',
      );
    }

    final session = ref.read(sessionProvider.notifier);
    final auth = ref.read(authApiProvider);
    final store = ref.read(tokenStoreProvider);

    // 1. Try refresh first if a refresh token is present in local store
    final storedRefresh = await store.loadRefreshToken();
    if (storedRefresh != null) {
      try {
        final pair = await auth.refresh(storedRefresh);
        await store.saveRefreshToken(pair.refreshToken);
        session.setAuthenticatedSession(pair.user, pair.accessToken);
        return;
      } catch (_) {
        // Refresh failed; proceed to credentials sign-in
      }
    }

    // 2. Try login with built-in credentials
    try {
      final pair = await auth.signIn(localEmail, localPassword);
      await store.saveRefreshToken(pair.refreshToken);
      session.setAuthenticatedSession(pair.user, pair.accessToken);
      return;
    } on UnauthorizedError {
      // 3. On 401: try register once
      try {
        final pair = await auth.signUp(
          localEmail,
          localPassword,
          displayName: 'Local Owner',
          inviteCode: localInviteCode.isEmpty ? null : localInviteCode,
        );
        await store.saveRefreshToken(pair.refreshToken);
        session.setAuthenticatedSession(pair.user, pair.accessToken);
        return;
      } on ConflictError {
        throw StateError(
          'The built-in account exists with a different password. '
          'Check dart_defines.json.',
        );
      } on RateLimitError catch (e) {
        final seconds = e.retryAfterSeconds;
        throw StateError(
          'Rate limit exceeded. Please retry in $seconds seconds.',
        );
      }
    } on ConflictError {
      throw StateError(
        'The built-in account exists with a different password. '
        'Check dart_defines.json.',
      );
    } on RateLimitError catch (e) {
      final seconds = e.retryAfterSeconds;
      throw StateError(
        'Rate limit exceeded. Please retry in $seconds seconds.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    // In build phases without sign-in UI, signOut resets session and re-runs silent login
    final session = ref.read(sessionProvider.notifier);
    await session.signOut();
  }
}

// ---------------------------------------------------------------------------
// Phase 8 Note:
// [AccountAuthStrategy] will be added here in Phase 8 to restore interactive
// sign-in, registration, profile, and account management screens.
// ---------------------------------------------------------------------------
