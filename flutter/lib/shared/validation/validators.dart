/// Pure validation helpers sharing the same rules as the Event Nu backend.
///
/// Character bounds mirror the Go validators, which count runes (code points)
/// rather than UTF-16 code units.
library;

int _runes(String value) => value.runes.length;

/// Backend rule: username is required and must be between 3 and 32 runes.
String? validateHandleInput(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Pick a handle';
  if (_runes(value) < 3) return 'Username must be at least 3 characters';
  if (_runes(value) > 32) return 'Username must be 32 characters or fewer';
  return null;
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Backend rule: email must look like an address and stay within 254 runes.
String? validateEmailInput(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Enter your email';
  if (_runes(value) > 254) return 'Email is too long';
  if (!_emailRe.hasMatch(value)) return 'Enter a valid email';
  return null;
}

/// Backend rule: password must be between 8 and 72 runes.
String? validatePasswordInput(String? raw) {
  final value = raw ?? '';
  if (value.isEmpty) return 'Create a password';
  if (_runes(value) < 8) return 'Use at least 8 characters';
  if (_runes(value) > 72) return 'Keep it under 72 characters';
  return null;
}

/// Backend rule: required free-text field bounded by [min] and [max] runes.
String? validateRequiredText(
  String? raw, {
  required String label,
  required int min,
  required int max,
}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return '$label is required';
  if (_runes(value) < min) return '$label must be at least $min characters';
  if (_runes(value) > max) return '$label must be $max characters or fewer';
  return null;
}

/// Backend rule: optional free-text field bounded by [max] runes.
String? validateOptionalMax(
  String? raw, {
  required String label,
  required int max,
}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (_runes(value) > max) return '$label must be $max characters or fewer';
  return null;
}

/// Mirrors the backend slugification: lowercase, then any run of characters
/// outside `[a-z0-9]` collapses into a single hyphen, and hyphens are trimmed
/// from both ends.
String slugify(String input) {
  final collapsed = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Rough 0-4 password strength score backing the design's strength meter.
int passwordStrength(String password) {
  final n = _runes(password);
  if (n < 8) return 0;
  var score = 1; // meets the minimum length
  if (n >= 10) score++;
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  if (hasLower && hasUpper && hasDigit) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  return score.clamp(0, 4);
}