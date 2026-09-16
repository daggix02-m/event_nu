import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

import 'data/organizer_application.dart';

/// Talks to the organizer-application endpoints.
///
/// Both calls require an authenticated session (the auth interceptor adds the
/// bearer token). `apply` is idempotent at the backend; a second pending
/// application answers with `409 application_pending`.
class OrganizerRepository {
  OrganizerRepository(this._api);

  static const String _path = '/api/v1/organizer-applications';

  final ApiClient _api;

  Future<OrganizerApplication> apply({
    required String requestedName,
    required String requestedSlug,
    required String bio,
  }) async {
    final data = await _api.post(
      _path,
      data: <String, String>{
        'requested_name': requestedName,
        'requested_slug': requestedSlug,
        'bio': bio,
      },
    );
    return _parse(data);
  }

  Future<OrganizerApplication> getMyApplication() async {
    final data = await _api.get('$_path/me');
    return _parse(data);
  }

  OrganizerApplication _parse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'bad_response',
        message: 'Unexpected response shape.',
      );
    }
    return OrganizerApplication.fromJson(data);
  }
}