import '../../core/api/api_exception.dart';

/// Which form a server error was raised from, so field-level collisions can be
/// placed on the right controls.
enum FormScope { auth, organizer }

/// Field-level error payload for a form.
///
/// Only one or two members are usually populated; the rest stay null.
/// `form` is a general error shown near the submit button; `retryAfterSeconds`
/// is populated when the backend rate limits the caller (HTTP 429).
class FieldErrors {
  const FieldErrors({
    this.username,
    this.email,
    this.password,
    this.requestedName,
    this.requestedSlug,
    this.bio,
    this.form,
    this.retryAfterSeconds,
  });

  final String? username;
  final String? email;
  final String? password;
  final String? requestedName;
  final String? requestedSlug;
  final String? bio;
  final String? form;
  final int? retryAfterSeconds;

  bool get isRateLimited => retryAfterSeconds != null;

  bool get isEmpty =>
      username == null &&
      email == null &&
      password == null &&
      requestedName == null &&
      requestedSlug == null &&
      bio == null &&
      form == null &&
      retryAfterSeconds == null;
}

const String _genericMessage = 'Something went wrong. Please try again later.';

/// Maps a caught error (usually an [ApiException]) into per-field messages.
///
/// Known backend shapes:
/// - 409 `email_taken` / `username_taken` -> field errors (register)
/// - 409 `application_pending` -> general error (organizer application)
/// - 422 `validation_error` -> general error carrying the first field message
/// - 401 `invalid_credentials` -> general error (sign in)
/// - 429 `too_many_requests` -> rate limited with a wait (seconds)
/// - any other -> general error with the server message
FieldErrors mapServerFormError(
  Object error, {
  FormScope scope = FormScope.auth,
}) {
  if (error is! ApiException) {
    return const FieldErrors(form: _genericMessage);
  }

  if (error.isRateLimited) {
    final retry = error.retryAfter ?? 60;
    return FieldErrors(
      form: 'Too many attempts. Try again in $retry\u00a0s.',
      retryAfterSeconds: retry,
    );
  }

  if (error.statusCode == 409) {
    switch (scope) {
      case FormScope.auth:
        return switch (error.code) {
          'email_taken' => FieldErrors(email: error.message),
          'username_taken' => FieldErrors(username: error.message),
          _ => FieldErrors(form: error.message),
        };
      case FormScope.organizer:
        return FieldErrors(form: error.message);
    }
  }

  return FieldErrors(form: error.message);
}