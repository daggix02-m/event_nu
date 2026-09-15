import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/data/auth_tokens.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
  });

  final TokenStorage storage;

  Future<AuthResponse> Function(String refreshToken)? _refreshAction;
  Future<void> Function()? _onRefreshFailed;
  Dio? _dio;

  String? _accessToken;
  Future<AuthResponse>? _inflightRefresh;

  void attachDio(Dio dio) => _dio = dio;

  void setAccessToken(String? token) => _accessToken = token;

  void setRefreshAction(Future<AuthResponse> Function(String refreshToken) action) {
    _refreshAction = action;
  }

  void setOnRefreshFailed(Future<void> Function() action) {
    _onRefreshFailed = action;
  }

  static const _retryKey = 'auth_refresh_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final original = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        original.extra[_retryKey] == true ||
        original.path.endsWith('/auth/refresh') ||
        original.path.endsWith('/auth/login') ||
        original.path.endsWith('/auth/register')) {
      handler.next(err);
      return;
    }

    try {
      final tokens = await _refreshOnce();
      final retried = await _retry(original, tokens.tokens.accessToken);
      handler.resolve(retried);
    } catch (_) {
      await _onRefreshFailed?.call();
      handler.next(err);
    }
  }

  Future<AuthResponse> _refreshOnce() {
    final inflight = _inflightRefresh;
    if (inflight != null) {
      return inflight;
    }
    final future = _performRefresh().whenComplete(() => _inflightRefresh = null);
    _inflightRefresh = future;
    return future;
  }

  Future<AuthResponse> _performRefresh() async {
    final action = _refreshAction;
    if (action == null) {
      throw const ApiRefreshException('refresh action not wired');
    }
    final refreshToken = await storage.read(TokenKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiRefreshException('no refresh token stored');
    }
    final response = await action(refreshToken);
    _accessToken = response.tokens.accessToken;
    await storage.write(TokenKeys.accessToken, response.tokens.accessToken);
    await storage.write(TokenKeys.refreshToken, response.tokens.refreshToken);
    await storage.write(
      TokenKeys.accessTokenExpiry,
      response.tokens.expiresAt.toIso8601String(),
    );
    return response;
  }

  Future<Response<dynamic>> _retry(RequestOptions original, String accessToken) async {
    final dio = _dio;
    if (dio == null) {
      throw const ApiRefreshException('dio not attached');
    }
    final headers = Map<String, dynamic>.from(original.headers)
      ..['Authorization'] = 'Bearer $accessToken';
    final extra = Map<String, dynamic>.from(original.extra)..[_retryKey] = true;
    return dio.fetch<dynamic>(original.copyWith(headers: headers, extra: extra));
  }
}

class ApiRefreshException implements Exception {
  const ApiRefreshException(this.message);

  final String message;

  @override
  String toString() => 'ApiRefreshException($message)';
}