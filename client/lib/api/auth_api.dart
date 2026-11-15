/// Authentication API calls.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

// ---------------------------------------------------------------------------
// AuthApi
// ---------------------------------------------------------------------------

/// Wraps the `/auth/*` and `/me` endpoints.
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  /// Signs in an existing user; returns [TokenPair] with user info.
  Future<TokenPair> signIn(String email, String password) async {
    final data = await _client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return TokenPair.fromJson(data as Map<String, dynamic>);
  }

  /// Registers a new user; returns [TokenPair] with user info.
  Future<TokenPair> signUp(
    String email,
    String password, {
    String? displayName,
    String? inviteCode,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
      if (inviteCode != null && inviteCode.isNotEmpty)
        'invite_code': inviteCode,
    };
    final data = await _client.post('/auth/register', body);
    return TokenPair.fromJson(data as Map<String, dynamic>);
  }

  /// Exchanges a refresh token for a new [TokenPair].
  Future<TokenPair> refresh(String refreshToken) async {
    final data = await _client.post('/auth/refresh', {
      'refresh_token': refreshToken,
    });
    return TokenPair.fromJson(data as Map<String, dynamic>);
  }

  /// Revokes the refresh token (server-side logout).
  Future<void> signOut(String refreshToken) async {
    await _client.post('/auth/logout', {'refresh_token': refreshToken});
  }

  /// Returns the authenticated user's profile.
  Future<UserOut> getMe() async {
    final data = await _client.get('/me');
    return UserOut.fromJson(data as Map<String, dynamic>);
  }
}
