/// Session state management via Riverpod.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/errors.dart';
import '../api/models.dart';
import 'auth_strategy.dart';
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
    this.isConnecting = false,
    this.connectingMessage,
    this.error,
  });

  final UserOut? user;
  final String? accessToken;
  final bool isLoading;
  final bool isConnecting;
  final String? connectingMessage;
  final String? error;

  bool get isSignedIn => user != null && accessToken != null;

  SessionState copyWith({
    UserOut? user,
    String? accessToken,
    bool? isLoading,
    bool? isConnecting,
    String? connectingMessage,
    String? error,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return SessionState(
      user: clearUser ? null : (user ?? this.user),
      accessToken: clearToken ? null : (accessToken ?? this.accessToken),
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      connectingMessage: connectingMessage ?? this.connectingMessage,
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
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(() => _initSession());
    return const SessionState(isLoading: true);
  }

  AuthApi get _auth => ref.read(authApiProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);
  ApiClient get _client => ref.read(apiClientProvider);

  // ---------------------------------------------------------------------------
  // Session initialization
  // ---------------------------------------------------------------------------

  Future<void> _initSession() async {
    try {
      await _client.loadCustomBaseUrl();
      final strategy = ref.read(authStrategyProvider);
      await strategy.ensureSignedIn();
    } catch (e) {
      state = SessionState(isLoading: false, error: e.toString());
    }
  }

  /// Sets an active authenticated session with user profile and access token.
  void setAuthenticatedSession(UserOut user, String accessToken) {
    _wireApiClient(accessToken);
    state = SessionState(
      user: user,
      accessToken: accessToken,
      isLoading: false,
      isConnecting: false,
    );
  }

  /// Sets connecting/retry status on startup when the backend is unreachable.
  void setConnectingStatus(String message) {
    state = state.copyWith(
      isLoading: true,
      isConnecting: true,
      connectingMessage: message,
      clearError: true,
    );
  }

  /// Continues into the application with an offline guest session when the
  /// server cannot be reached, allowing access to cached data and UI shell.
  void continueOffline() {
    state = SessionState(
      user: UserOut(
        id: 'offline_user',
        email: 'offline@melodia.local',
        displayName: 'Guest (Offline)',
        createdAt: DateTime.now(),
      ),
      accessToken: 'offline_access_token',
      isLoading: false,
    );
  }

  /// Updates and persists the backend server URL in SharedPreferences.
  Future<void> updateServerUrl(String newUrl) async {
    final trimmed = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_api_url', trimmed);
    } catch (_) {}
    _client.updateBaseUrl(trimmed);
    ref.invalidate(sessionProvider);
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
      setAuthenticatedSession(pair.user, pair.accessToken);
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
      setAuthenticatedSession(pair.user, pair.accessToken);
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
        // Best-effort
      }
    }
    await _store.clearRefreshToken();
    _client.clearAccessToken();
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
