import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/auth_api.dart';
import 'package:melodia/api/errors.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/session/auth_strategy.dart';
import 'package:melodia/session/session_controller.dart';
import 'package:melodia/session/token_store.dart';

class FakeAuthApi implements AuthApi {
  bool signInCalled = false;
  bool signUpCalled = false;
  bool refreshCalled = false;

  bool throw401OnSignIn = false;
  bool throw409OnSignUp = false;

  final testUser = UserOut(
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Local Owner',
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
  );

  @override
  Future<TokenPair> signIn(String email, String password) async {
    signInCalled = true;
    if (throw401OnSignIn) {
      throw const UnauthorizedError('Invalid credentials');
    }
    return TokenPair(
      accessToken: 'access-123',
      refreshToken: 'refresh-123',
      tokenType: 'bearer',
      expiresIn: 3600,
      user: testUser,
    );
  }

  @override
  Future<TokenPair> signUp(String email, String password,
      {String? displayName, String? inviteCode}) async {
    signUpCalled = true;
    if (throw409OnSignUp) {
      throw const ConflictError('Account already exists');
    }
    return TokenPair(
      accessToken: 'access-created-123',
      refreshToken: 'refresh-created-123',
      tokenType: 'bearer',
      expiresIn: 3600,
      user: testUser,
    );
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    refreshCalled = true;
    return TokenPair(
      accessToken: 'access-refreshed',
      refreshToken: 'refresh-refreshed',
      tokenType: 'bearer',
      expiresIn: 3600,
      user: testUser,
    );
  }

  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  Future<UserOut> getMe() async => testUser;
}

class FakeTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> loadRefreshToken() async => token;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    token = refreshToken;
  }

  @override
  Future<void> clearRefreshToken() async {
    token = null;
  }
}

void main() {
  group('SilentAuthStrategy', () {
    test('needsUi is false', () {
      final container = ProviderContainer();
      final strategy =
          SilentAuthStrategy(container.read(sessionProvider.notifier).ref);
      expect(strategy.needsUi, isFalse);
    });

    test('signs in directly if credentials are valid', () async {
      final fakeAuth = FakeAuthApi();
      final fakeStore = FakeTokenStore();

      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWithValue(fakeAuth),
          tokenStoreProvider.overrideWithValue(fakeStore),
        ],
      );

      final strategy =
          SilentAuthStrategy(container.read(sessionProvider.notifier).ref);
      await strategy.ensureSignedIn();

      expect(fakeAuth.signInCalled, isTrue);
      expect(fakeAuth.signUpCalled, isFalse);
      expect(fakeStore.token, equals('refresh-123'));
      expect(container.read(sessionProvider).user?.id, equals('user-123'));
    });

    test('on 401 falls back to registration and sets authenticated session',
        () async {
      final fakeAuth = FakeAuthApi()..throw401OnSignIn = true;
      final fakeStore = FakeTokenStore();

      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWithValue(fakeAuth),
          tokenStoreProvider.overrideWithValue(fakeStore),
        ],
      );

      final strategy =
          SilentAuthStrategy(container.read(sessionProvider.notifier).ref);
      await strategy.ensureSignedIn();

      expect(fakeAuth.signInCalled, isTrue);
      expect(fakeAuth.signUpCalled, isTrue);
      expect(fakeStore.token, equals('refresh-created-123'));
      expect(container.read(sessionProvider).user?.id, equals('user-123'));
    });

    test('on 401 with existing conflicting account throws StateError', () async {
      final fakeAuth = FakeAuthApi()
        ..throw401OnSignIn = true
        ..throw409OnSignUp = true;
      final fakeStore = FakeTokenStore();

      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWithValue(fakeAuth),
          tokenStoreProvider.overrideWithValue(fakeStore),
        ],
      );

      final strategy =
          SilentAuthStrategy(container.read(sessionProvider.notifier).ref);
      expect(
        () => strategy.ensureSignedIn(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Check dart_defines.json'),
        )),
      );
    });
  });
}
