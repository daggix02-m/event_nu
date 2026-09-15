import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.retryAfter,
    this.cause,
  });

  final String code;
  final String message;
  final int? statusCode;
  final int? retryAfter;
  final Object? cause;

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($code, $statusCode, $message)';

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return ApiException(
        code: 'network_error',
        message: 'No internet connection. Check your connection and try again.',
        statusCode: status,
        cause: error,
      );
    }
    if (error.response == null) {
      return ApiException(
        code: 'network_error',
        message: 'No internet connection. Check your connection and try again.',
        statusCode: status,
        cause: error,
      );
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final envelope = data['error'];
      if (envelope is Map<String, dynamic>) {
        final code = (envelope['code'] as String?) ?? 'unknown';
        final message = (envelope['message'] as String?) ?? 'Something went wrong.';
        final retryAfter = error.response?.headers
            .value('retry-after')
            ?.let((v) => v is String ? int.tryParse(v) : null);
        return ApiException(
          code: code,
          message: message,
          statusCode: status,
          retryAfter: retryAfter,
          cause: error,
        );
      }
    }
    return ApiException(
      code: 'unknown',
      message: 'Something went wrong. Please try again later.',
      statusCode: status,
      cause: error,
    );
  }
}

extension _Let on Object? {
  T? let<T>(T Function(Object?) fn) => this == null ? null : fn(this);
}