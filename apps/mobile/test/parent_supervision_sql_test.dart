import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File('../../supabase/parent_supervision.sql').readAsStringSync();
  });

  test('creates dedicated supervision storage and cancellation state', () {
    expect(
      migration,
      contains("alter type public.link_status add value 'cancelled'"),
    );
    expect(
      migration,
      contains(
        'create table if not exists public.supervision_notifications',
      ),
    );
    expect(
      migration,
      contains('create table if not exists public.screen_time_sync_events'),
    );
    expect(
      migration,
      contains('create table if not exists public.screen_time_threshold_events'),
    );
    expect(migration, contains('parent_child_links_one_live_pair_idx'));
    expect(
      migration,
      contains('supervision_notifications_user_created_idx'),
    );
  });

  test('removes direct sensitive writes and enables owner-scoped reads', () {
    expect(
      migration,
      contains(
        'revoke insert, update, delete on public.parent_child_links from authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'revoke insert, update, delete on public.check_ins from authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'revoke insert, update, delete on public.sos_alerts from authenticated',
      ),
    );
    expect(migration, contains('Users view own supervision notifications'));
    expect(migration, contains('Active family views child safety records'));
  });

  test('publishes live supervision tables', () {
    expect(
      migration,
      contains(
        'alter publication supabase_realtime add table public.parent_child_links',
      ),
    );
    expect(
      migration,
      contains(
        'alter publication supabase_realtime add table public.sos_alerts',
      ),
    );
    expect(
      migration,
      contains(
        'alter publication supabase_realtime add table public.supervision_notifications',
      ),
    );
  });

  test('defines server-authoritative family link transitions', () {
    for (final name in [
      'create_parent_child_link',
      'accept_parent_child_link',
      'reject_parent_child_link',
      'cancel_parent_child_link',
    ]) {
      expect(migration, contains('function public.$name'));
    }
    expect(
      migration,
      contains("p_requester_role not in ('parent', 'child')"),
    );
    expect(migration, contains('requested_by <> v_user_id'));
    expect(migration, contains('requested_by = v_user_id'));
    expect(migration, contains("status <> 'pending'"));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains("'link_request'"));
    expect(migration, contains("'link_accepted'"));
    expect(migration, contains("'link_rejected'"));
    expect(migration, contains("'link_cancelled'"));
  });

  test('defines child-only safety and parent-only SOS transitions', () {
    for (final name in [
      'submit_safety_check_in',
      'submit_sos_alert',
      'acknowledge_sos_alert',
      'resolve_sos_alert',
      'mark_supervision_notification_read',
    ]) {
      expect(migration, contains('function public.$name'));
    }
    expect(migration, contains('No active parent link'));
    expect(migration, contains("status = 'open'"));
    expect(migration, contains("status = 'acknowledged'"));
    expect(migration, contains("status = 'resolved'"));
    expect(migration, contains('acknowledged_by is null'));
    expect(migration, contains("'Location unavailable'"));
  });
}
