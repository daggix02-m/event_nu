import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_exception.dart';
import 'package:event_nu/shared/validation/form_errors.dart';

void main() {
  ApiException conflict(String code, String message) => ApiException(
        code: code,
        message: message,
        statusCode: 409,
      );

  group('auth scope', () {
    test('maps email_taken to the email field', () {
      final errors = mapServerFormError(conflict('email_taken', 'An account with this email already exists.'));
      expect(errors.email, contains('already exists'));
      expect(errors.username, isNull);
      expect(errors.form, isNull);
    });

    test('maps username_taken to the username field', () {
      final errors = mapServerFormError(conflict('username_taken', 'This username is already taken.'));
      expect(errors.username, contains('already taken'));
      expect(errors.email, isNull);
    });

    test('maps validation_error to the form message', () {
      final errors = mapServerFormError(const ApiException(
        code: 'validation_error',
        message: 'username must be at least 3 characters.',
        statusCode: 422,
      ));
      expect(errors.form, contains('username'));
    });

    test('maps invalid_credentials (401) to the form message', () {
      final errors = mapServerFormError(const ApiException(
        code: 'invalid_credentials',
        message: 'Invalid email or password.',
        statusCode: 401,
      ));
      expect(errors.form, contains('Invalid email or password'));
    });

    test('maps 429 with Retry-After to a rate limited result', () {
      final errors = mapServerFormError(ApiException(
        code: 'too_many_requests',
        message: 'Too many attempts.',
        statusCode: 429,
        retryAfter: 30,
      ));
      expect(errors.isRateLimited, isTrue);
      expect(errors.retryAfterSeconds, 30);
      expect(errors.form, contains('30'));
    });

    test('defaults retry wait to 60 seconds when Retry-After is missing', () {
      final errors = mapServerFormError(const ApiException(
        code: 'too_many_requests',
        message: 'Too many attempts.',
        statusCode: 429,
      ));
      expect(errors.retryAfterSeconds, 60);
    });

    test('exposes network errors on the form', () {
      final errors = mapServerFormError(const ApiException(
        code: 'network_error',
        message: 'No internet connection. Check your connection and try again.',
      ));
      expect(errors.form, contains('internet'));
    });

    test('falls back to the server message for unknown conflicts', () {
      final errors = mapServerFormError(conflict('who_knows', 'Unexpected conflict.'));
      expect(errors.form, 'Unexpected conflict.');
    });
  });

  group('organizer scope', () {
    test('maps application_pending to the form message', () {
      final errors = mapServerFormError(
        conflict('application_pending', 'You already have a pending organizer application.'),
        scope: FormScope.organizer,
      );
      expect(errors.requestedName, isNull);
      expect(errors.form, contains('pending'));
    });

    test('maps organizer validation_error to the form message', () {
      final errors = mapServerFormError(
        const ApiException(
          code: 'validation_error',
          message: 'requested_name must be at least 3 characters.',
          statusCode: 422,
        ),
        scope: FormScope.organizer,
      );
      expect(errors.form, contains('requested_name'));
    });

    test('surfaces rate limits for organizer submissions too', () {
      final errors = mapServerFormError(
        const ApiException(
          code: 'too_many_requests',
          message: 'Too many attempts.',
          statusCode: 429,
        ),
        scope: FormScope.organizer,
      );
      expect(errors.isRateLimited, isTrue);
    });
  });

  group('non API exceptions', () {
    test('falls back to a generic message', () {
      final errors = mapServerFormError(Exception('boom'));
      expect(errors.form, isNotNull);
      expect(errors.isEmpty, isFalse);
    });
  });
}