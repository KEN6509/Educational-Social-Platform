import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tags SQL removes the obsolete tag request workflow', () {
    final sql = File('../../supabase/tags.sql').readAsStringSync();

    expect(sql, contains('drop table if exists public.tag_requests;'));
    expect(
      sql,
      isNot(contains('create table if not exists public.tag_requests')),
    );
    expect(sql, isNot(contains('on public.tag_requests')));
  });
}
