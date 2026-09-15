import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_envelope.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this.dio,
  });

  final Dio dio;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get<dynamic>(path, queryParameters: queryParameters);
      return ApiEnvelope.unwrap(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    }
  }

  Future<dynamic> post(
    String path, {
    Object? data,
  }) async {
    try {
      final response = await dio.post<dynamic>(path, data: data);
      return ApiEnvelope.unwrap(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    }
  }

  Future<dynamic> patch(
    String path, {
    Object? data,
  }) async {
    try {
      final response = await dio.patch<dynamic>(path, data: data);
      return ApiEnvelope.unwrap(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    }
  }

  Future<dynamic> delete(
    String path, {
    Object? data,
  }) async {
    try {
      final response = await dio.delete<dynamic>(path, data: data);
      return ApiEnvelope.unwrap(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    }
  }
}

final class ApiEnvironment {
  static const tokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const accessTokenExpiryKey = 'access_token_expiry';

  static String resolveBaseUrl({String? override}) {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (override != null && override.isNotEmpty) return override;
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://localhost:8080';
  }

  static String resolveDeviceIdentifier(String override) {
    if (override.isNotEmpty) return override;
    return _platformFallback;
  }

  static String get _platformFallback {
    if (Platform.isLinux) return 'linux-e2e';
    if (Platform.isAndroid) return 'android-dev';
    if (Platform.isIOS) return 'ios-dev';
    return 'desktop-dev';
  }
}