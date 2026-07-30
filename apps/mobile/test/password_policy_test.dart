import 'package:cyanzone_mobile/src/core/security/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('requires at least 12 characters', () {
      final result = PasswordPolicy.evaluate('Short1.');

      expect(result.hasMinimumLength, isFalse);
      expect(result.isValid, isFalse);
    });

    test('requires an uppercase letter', () {
      final result = PasswordPolicy.evaluate('lowercasepass1.');

      expect(result.hasUppercase, isFalse);
      expect(result.isValid, isFalse);
    });

    test('requires a lowercase letter', () {
      final result = PasswordPolicy.evaluate('UPPERCASEPASS1.');

      expect(result.hasLowercase, isFalse);
      expect(result.isValid, isFalse);
    });

    test('requires a number', () {
      final result = PasswordPolicy.evaluate('NoNumberHere.');

      expect(result.hasNumber, isFalse);
      expect(result.isValid, isFalse);
    });

    test('requires a non-whitespace symbol', () {
      final noSymbol = PasswordPolicy.evaluate('NoSymbolHere1');
      final whitespaceOnly = PasswordPolicy.evaluate('StrongPass12 ');

      expect(noSymbol.hasSymbol, isFalse);
      expect(whitespaceOnly.hasSymbol, isFalse);
      expect(noSymbol.isValid, isFalse);
      expect(whitespaceOnly.isValid, isFalse);
    });

    test('period and underscore are accepted symbols', () {
      expect(PasswordPolicy.evaluate('StrongPass12.').isValid, isTrue);
      expect(PasswordPolicy.evaluate('StrongPass12_').isValid, isTrue);
    });

    test('returns consistent registration validation guidance', () {
      expect(
        PasswordPolicy.validationError('weakpassword'),
        'Use at least 12 characters with uppercase, lowercase, a number, '
        'and a symbol such as . or _.',
      );
      expect(PasswordPolicy.validationError('StrongPass12.'), isNull);
    });
  });
}
