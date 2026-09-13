import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const submitFunction = 'submit_creator_verification_request';

  test('mobile submits creator applications through the protected RPC', () {
    final source = File(
      'lib/src/features/profile/presentation/verified_badge_page.dart',
    ).readAsStringSync();

    expect(source, contains(submitFunction));
    expect(
      source,
      isNot(contains("from('content_creator_requests').insert")),
    );
  });

  test('canonical schema enforces the two-follower creator gate', () {
    final sql = File('../../supabase/schema.sql').readAsStringSync();

    _expectCreatorGate(sql);
  });

  test('existing-project migration safely installs the creator gate', () {
    final sql = File(
      '../../supabase/creator_follower_gate.sql',
    ).readAsStringSync();

    _expectCreatorGate(sql);
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('truncate table')));
    expect(sql, isNot(contains('delete from public.content_creator_requests')));
  });
}

void _expectCreatorGate(String sql) {
  expect(
    sql,
    contains(
      'create or replace function public.submit_creator_verification_request',
    ),
  );
  expect(sql, contains('from public.follows'));
  expect(sql, contains('following_id = v_user_id'));
  expect(sql, contains('v_follower_count < 2'));
  expect(sql, contains('At least 2 followers are required'));
  expect(sql, contains('Users can request creator status'));
  expect(sql, contains('select count(*)'));
  expect(
    sql,
    contains(
      'grant execute on function public.submit_creator_verification_request(text) to authenticated',
    ),
  );
  expect(
    sql,
    contains(
      'revoke all on function public.submit_creator_verification_request(text) from public',
    ),
  );
}
