import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/data/auth_tokens.dart';
import '../../features/auth/data/user.dart';
import '../api/api_exception.dart';
import '../storage/token_storage.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthStateUnknown extends AuthState {
  const AuthStateUnknown();
}

final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

final class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated({required this.user});

  final User user;
}

class SessionController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  bool _bootstrapped = false;

  /// True once [restore] has finished, i.e. the initial session restore has
  /// concluded. Used by the router to show a branded splash before the first
  /// decision about the destination screen.
  bool get bootstrapped => _bootstrapped;

  @override
  Future<AuthState> build() async {
    return const AuthStateUnknown();
  }

  Future<void> restore() async {
    state = const AsyncLoading();
    final access = await _storage.read(TokenKeys.accessToken);
    if (access == null || access.isEmpty) {
      _bootstrapped = true;
      state = const AsyncData(AuthStateUnauthenticated());
      return;
    }
    try {
      final user = await _repository.fetchMe();
      _bootstrapped = true;
      state = AsyncData(AuthStateAuthenticated(user: user));
    } on ApiException catch (e) {
      _bootstrapped = true;
      if (e.isUnauthorized) {
        state = const AsyncData(AuthStateUnauthenticated());
        await clearSession();
      } else {
        state = AsyncError(e, StackTrace.current);
      }
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await _repository.login(email: email, password: password);
      await _persist(response);
      state = AsyncData(AuthStateAuthenticated(user: response.user));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await _repository.register(
        email: email,
        password: password,
        username: username,
      );
      await _persist(response);
      state = AsyncData(AuthStateAuthenticated(user: response.user));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> verifyCode(String code) async {
    final current = state.value;
    final user = current is AuthStateAuthenticated ? current.user : null;
    final access = await _storage.read(TokenKeys.accessToken);
    if (user == null || access == null) {
      throw const ApiException(
        code: 'unauthorized',
        message: 'Sign in again to continue.',
        statusCode: 401,
      );
    }
    try {
      final verified = await _repository.verify(code: code, accessToken: access);
      if (!verified.verified) {
        throw const ApiException(code: 'invalid_code', message: 'The code is invalid.');
      }
      final updated = await _repository.fetchMe();
      state = AsyncData(
        AuthStateAuthenticated(user: user.copyWith(isVerified: updated.isVerified)),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout({bool notifyBackend = true}) async {
    final refreshToken = await _storage.read(TokenKeys.refreshToken);
    if (notifyBackend && refreshToken != null) {
      try {
        await _repository.logout(
          refreshToken: refreshToken,
          accessToken: await _storage.read(TokenKeys.accessToken) ?? '',
        );
      } on ApiException {
        state = const AsyncData(AuthStateUnauthenticated());
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    await _storage.delete(TokenKeys.accessToken);
    await _storage.delete(TokenKeys.refreshToken);
    await _storage.delete(TokenKeys.accessTokenExpiry);
    state = const AsyncData(AuthStateUnauthenticated());
  }

  Future<void> _persist(AuthResponse response) async {
    await _storage.write(TokenKeys.accessToken, response.tokens.accessToken);
    await _storage.write(TokenKeys.refreshToken, response.tokens.refreshToken);
    await _storage.write(
      TokenKeys.accessTokenExpiry,
      response.tokens.expiresAt.toIso8601String(),
    );
    ref.read(authInterceptorProvider).setAccessToken(response.tokens.accessToken);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, AuthState>(SessionController.new);