/// Session state management via Riverpod.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/errors.dart';
import '../api/models.dart';
import 'token_store.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable session state.
class SessionState {
  const SessionState({
    this.user,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  final UserOut? user;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  bool get isSignedIn => user != null && accessToken != null;

  SessionState copyWith({
    UserOut? user,
    String? accessToken,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return SessionState(
      user: clearUser ? null : (user ?? this.user),
      accessToken: clearToken ? null : (accessToken ?? this.accessToken),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// The main session provider. Subscribe to this for user / auth state.
final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience derived provider — true when the user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isSignedIn;
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Riverpod [Notifier] that manages the authenticated session lifecycle.
///
/// On construction it attempts to restore a session from the stored refresh
/// token (showing [SessionState.isLoading] = true during the attempt).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Kick off async restore; we return the loading state synchronously.
    _restoreSession();
    return const SessionState(isLoading: true);
  }

  AuthApi get _auth => ref.read(authApiProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);
  ApiClient get _client => ref.read(apiClientProvider);

  // ---------------------------------------------------------------------------
  // Session restore
  // ---------------------------------------------------------------------------

  Future<void> _restoreSession() async {
    final stored = await _store.loadRefreshToken();
    if (stored == null) {
      state = const SessionState(isLoading: false);
      _wireApiClient(null);
      return;
    }
    try {
      final pair = await _auth.refresh(stored);
      await _store.saveRefreshToken(pair.refreshToken);
      _wireApiClient(pair.accessToken);
      state = SessionState(
        user: pair.user,
        accessToken: pair.accessToken,
        isLoading: false,
      );
    } catch (_) {
      await _store.clearRefreshToken();
      _wireApiClient(null);
      state = const SessionState(isLoading: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Signs the user in with [email] and [password].
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final pair = await _auth.signIn(email, password);
      await _store.saveRefreshToken(pair.refreshToken);
      _wireApiClient(pair.accessToken);
      state = SessionState(
        user: pair.user,
        accessToken: pair.accessToken,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Registers a new account.
  Future<void> signUp(
    String email,
    String password, {
    String? displayName,
    String? inviteCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final pair = await _auth.signUp(
        email,
        password,
        displayName: displayName,
        inviteCode: inviteCode,
      );
      await _store.saveRefreshToken(pair.refreshToken);
      _wireApiClient(pair.accessToken);
      state = SessionState(
        user: pair.user,
        accessToken: pair.accessToken,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Signs the user out, revoking the refresh token and clearing local storage.
  Future<void> signOut() async {
    final storedToken = await _store.loadRefreshToken();
    if (storedToken != null) {
      try {
        await _auth.signOut(storedToken);
      } catch (_) {
        // Best-effort: even if the network call fails, clear local state.
      }
    }
    await _store.clearRefreshToken();
    _wireApiClient(null);
    state = const SessionState(isLoading: false);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Keeps the [ApiClient] in sync with the current access token and wires the
  /// refresh + session-expired callbacks.
  void _wireApiClient(String? accessToken) {
    if (accessToken != null) {
      _client.setAccessToken(accessToken);
    } else {
      _client.clearAccessToken();
    }

    _client.onRefreshNeeded = (String _) async {
      final stored = await _store.loadRefreshToken();
      if (stored == null) return null;
      try {
        final pair = await _auth.refresh(stored);
        await _store.saveRefreshToken(pair.refreshToken);
        _client.setAccessToken(pair.accessToken);
        // Update state silently (no loading flicker).
        state = state.copyWith(
          accessToken: pair.accessToken,
          user: pair.user,
        );
        return pair.accessToken;
      } catch (_) {
        return null;
      }
    };

    _client.onSessionExpired = () async {
      await _store.clearRefreshToken();
      _client.clearAccessToken();
      state = const SessionState(isLoading: false);
    };
  }
}
