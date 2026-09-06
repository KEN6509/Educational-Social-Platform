import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String authBaseline;

  setUpAll(() {
    migration =
        File('../../supabase/registration_consent_otp.sql').readAsStringSync();
    authBaseline = File('../../supabase/auth.sql').readAsStringSync();
  });

  test('email confirmation rejects missing current consent metadata', () {
    for (final sql in [migration, authBaseline]) {
      final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ');
      final validationStart = normalizedSql.indexOf("if tg_op = 'UPDATE'");
      final validationEnd = normalizedSql.indexOf(
        "raise exception 'Registration consent metadata is required'",
        validationStart,
      );

      expect(validationStart, greaterThanOrEqualTo(0));
      expect(validationEnd, greaterThan(validationStart));

      final validationSql = normalizedSql.substring(
        validationStart,
        validationEnd,
      );

      expect(
        validationSql,
        contains(
          "nullif(trim(new.raw_user_meta_data ->> 'terms_version'), '') "
          "is distinct from '1.0'",
        ),
      );
      expect(
        validationSql,
        contains(
          "nullif(trim(new.raw_user_meta_data ->> 'privacy_version'), '') "
          "is distinct from '1.0'",
        ),
      );
      expect(validationSql, contains("'consent_accepted_at'"));
      expect(validationSql, contains('is null'));
      expect(
        normalizedSql,
        contains("raise exception 'Registration consent metadata is required'"),
      );
    }
  });

  test('consent validation applies only to confirmation updates', () {
    for (final sql in [migration, authBaseline]) {
      final validationStart = sql.indexOf("if tg_op = 'UPDATE'");
      final profileInsert = sql.indexOf('insert into public.profiles');

      expect(validationStart, greaterThanOrEqualTo(0));
      expect(profileInsert, greaterThan(validationStart));
    }
  });
}
