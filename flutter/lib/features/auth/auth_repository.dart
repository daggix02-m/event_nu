import '../../../core/api/api_client.dart';

import 'data/auth_tokens.dart';
import 'data/user.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final data = await _api.post(
      '/api/v1/auth/register',
      data: <String, String>{
        'email': email,
        'password': password,
        'username': username,
      },
    );
    return _parseAuthResponse(data);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/api/v1/auth/login',
      data: <String, String>{'email': email, 'password': password},
    );
    return _parseAuthResponse(data);
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final data = await _api.post(
      '/api/v1/auth/refresh',
      data: <String, String>{'refresh_token': refreshToken},
    );
    return _parseAuthResponse(data);
  }

  Future<VerifiedResponse> verify({
    required String code,
    required String accessToken,
  }) async {
    final data = await _api.post(
      '/api/v1/auth/verify',
      data: <String, String>{'code': code},
    );
    return _parseVerified(data);
  }

  Future<void> logout({
    required String refreshToken,
    required String accessToken,
  }) async {
    await _api.post(
      '/api/v1/auth/logout',
      data: <String, String>{'refresh_token': refreshToken},
    );
  }

  Future<User> fetchMe() async {
    final data = await _api.get('/api/v1/users/me');
    return _parseUser(data);
  }

  AuthResponse _parseAuthResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const AuthParseException('auth response must be an object');
    }
    return AuthResponse.fromJson(data);
  }

  VerifiedResponse _parseVerified(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const AuthParseException('verify response must be an object');
    }
    return VerifiedResponse.fromJson(data);
  }

  User _parseUser(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const AuthParseException('user response must be an object');
    }
    return User.fromJson(data);
  }
}

class AuthParseException implements Exception {
  const AuthParseException(this.message);

  final String message;

  @override
  String toString() => 'AuthParseException($message)';
}