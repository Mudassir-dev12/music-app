/// Secure storage for the refresh token.
///
/// On web, flutter_secure_storage uses browser localStorage. This is acceptable
/// for v1 but XSS must be prevented. An httpOnly cookie would require a backend
/// change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return const TokenStore();
});

// ---------------------------------------------------------------------------
// TokenStore
// ---------------------------------------------------------------------------

const String _kRefreshTokenKey = 'melodia_refresh_token';

/// Thin wrapper around [FlutterSecureStorage] for the refresh token.
class TokenStore {
  const TokenStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    // Android: use EncryptedSharedPreferences when available.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Persists [token] to secure storage.
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _kRefreshTokenKey, value: token);
  }

  /// Returns the stored refresh token, or null if none is saved.
  Future<String?> loadRefreshToken() async {
    return _storage.read(key: _kRefreshTokenKey);
  }

  /// Removes the stored refresh token.
  Future<void> clearRefreshToken() async {
    await _storage.delete(key: _kRefreshTokenKey);
  }
}
