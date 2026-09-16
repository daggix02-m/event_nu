import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/shared/validation/validators.dart';

void main() {
  group('validateHandleInput', () {
    test('rejects empty and whitespace-only handles', () {
      expect(validateHandleInput(null), isNotNull);
      expect(validateHandleInput(''), isNotNull);
      expect(validateHandleInput('   '), isNotNull);
    });

    test('rejects handles shorter than 3 characters', () {
      expect(validateHandleInput('ab'), isNotNull);
      expect(validateHandleInput('ab'), contains('3'));
    });

    test('rejects handles longer than 32 characters', () {
      expect(validateHandleInput('a' * 33), isNotNull);
    });

    test('accepts handles between 3 and 32 characters', () {
      expect(validateHandleInput('daggi'), isNull);
      expect(validateHandleInput('a' * 32), isNull);
    });
  });

  group('validateEmailInput', () {
    test('rejects missing and malformed emails', () {
      expect(validateEmailInput(''), isNotNull);
      expect(validateEmailInput('not-an-email'), isNotNull);
      expect(validateEmailInput('a@b'), isNotNull); // no TLD
    });

    test('accepts a well-formed email', () {
      expect(validateEmailInput('dev@eventnu.test'), isNull);
    });
  });

  group('validatePasswordInput', () {
    test('requires at least 8 characters', () {
      expect(validatePasswordInput('short'), contains('8'));
      expect(validatePasswordInput(''), isNotNull);
    });

    test('rejects passwords over 72 characters', () {
      expect(validatePasswordInput('a' * 73), isNotNull);
    });

    test('accepts passwords between 8 and 72 characters', () {
      expect(validatePasswordInput('a' * 8), isNull);
      expect(validatePasswordInput('a' * 72), isNull);
    });
  });

  group('slugify', () {
    test('lowercases and collapses non-alphanumeric runs to a hyphen', () {
      expect(slugify('My Great Org'), 'my-great-org');
      expect(slugify('  Hello   World  '), 'hello-world');
      expect(slugify('Häagen-Dazs & Co'), 'h-agen-dazs-co');
    });

    test('trims leading and trailing hyphens', () {
      expect(slugify('- leading'), 'leading');
      expect(slugify('trailing -'), 'trailing');
    });

    test('returns empty string when nothing remains', () {
      expect(slugify('!!!'), '');
    });
  });

  group('passwordStrength', () {
    test('scores empty or short passwords at 0', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc'), 0);
    });

    test('scores longer passwords higher', () {
      expect(passwordStrength('abcdefgh'), greaterThan(0));
      expect(passwordStrength('Abcdefgh1!'), 4);
    });
  });
}