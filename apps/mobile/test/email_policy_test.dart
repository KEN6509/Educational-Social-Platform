import 'package:cyanzone_mobile/src/core/validation/email_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailPolicy', () {
    test('rejects empty and malformed email addresses', () {
      for (final email in [
        '',
        'name.example.com',
        'name@example',
        'name.with.dot@example',
        'name@@example.com',
        'name@foo,bar.com',
        'name@.com',
        'name@example.',
      ]) {
        expect(
          EmailPolicy.validationError(email),
          'Enter a valid email address.',
          reason: email,
        );
      }
    });

    test('accepts a valid-format email at 254 characters but not 255', () {
      final email =
          '${'a' * 64}@${'b' * 60}.${'b' * 60}.${'b' * 60}.${'c' * 6}';
      expect(email.length, 254);
      expect(EmailPolicy.validationError(email), isNull);
      expect(
        EmailPolicy.validationError('${email}d'),
        'Enter a valid email address.',
      );
    });
  });
}
