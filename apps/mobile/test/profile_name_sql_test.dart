import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh schema and migration enforce trimmed names of 1–24 characters',
      () {
    final schema = File('../../supabase/schema.sql').readAsStringSync();
    final migration =
        File('../../supabase/profile_name_policy.sql').readAsStringSync();
    const check = 'char_length(btrim(name)) between 1 and 24';

    expect(schema, contains(check));
    expect(migration, contains(check));
    expect(migration, contains('if exists'));
    expect(
      migration.indexOf('if exists'),
      lessThan(migration.indexOf('add constraint profiles_name_length_check')),
    );
    expect(
      migration,
      contains('validate constraint profiles_name_length_check'),
    );
  });
}
