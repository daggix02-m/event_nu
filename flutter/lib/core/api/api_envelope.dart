import 'api_exception.dart';

class ApiEnvelope {
  const ApiEnvelope._();

  static dynamic unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body['data'] != null) {
      return body['data'];
    }
    if (body is Map<String, dynamic> && body['data'] == null && body.containsKey('data')) {
      return null;
    }
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      throw ApiException(
        code: (body['error'] as Map<String, dynamic>)['code'] as String? ?? 'unknown',
        message: (body['error'] as Map<String, dynamic>)['message'] as String? ?? 'Something went wrong.',
      );
    }
    return body;
  }

  static Map<String, dynamic> unwrapObject(dynamic body) {
    final data = unwrap(body);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const ApiException(code: 'bad_response', message: 'Unexpected response shape.');
  }

  static List<dynamic> unwrapList(dynamic body) {
    final data = unwrap(body);
    if (data is List<dynamic>) {
      return data;
    }
    throw const ApiException(code: 'bad_response', message: 'Unexpected response shape.');
  }
}