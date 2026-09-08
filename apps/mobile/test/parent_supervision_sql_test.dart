import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String schema;
  late String readme;

  setUpAll(() {
    migration =
        File('../../supabase/parent_supervision.sql').readAsStringSync();
    schema = File('../../supabase/schema.sql').readAsStringSync();
    readme = File('../../supabase/README.md').readAsStringSync();
  });

  test('canonical schema matches parent supervision migration contracts', () {
    for (final token in [
      'supervision_notifications',
      'screen_time_sync_events',
      'screen_time_threshold_events',
      'create_parent_child_link',
      'request_parent_child_unlink',
      'accept_parent_child_unlink',
      'reject_parent_child_unlink',
      'submit_safety_check_in',
      'submit_sos_alert',
      'sync_screen_time_session',
    ]) {
      expect(schema, contains(token));
    }
    expect(schema, contains('screen_time_logs.user_id'));
  });

  test('Supabase README documents parent supervision rollout', () {
    expect(readme, contains('parent_supervision.sql'));
    expect(readme, contains('supervision_notifications'));
    expect(readme, contains('FCM remains deferred'));
    expect(readme, contains('in-app Realtime only'));
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
      contains(
          'create table if not exists public.screen_time_threshold_events'),
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

  test('defines server-authoritative live SOS location and event storage', () {
    for (final token in [
      'create table if not exists public.sos_live_locations',
      'create table if not exists public.sos_events',
      'update_sos_live_location',
      'fetch_active_sos_alert',
      "'triggered'",
      "'acknowledged'",
      "'resolved'",
      'sos_events_one_parent_ack_idx',
      'Current parent must acknowledge before resolving',
      'alter publication supabase_realtime add table public.sos_live_locations',
      'alter publication supabase_realtime add table public.sos_events',
    ]) {
      expect(migration, contains(token));
      expect(schema, contains(token));
    }
    for (final sql in [migration, schema]) {
      expect(
        sql,
        contains(
          'revoke insert, update, delete on public.sos_live_locations from authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'revoke insert, update, delete on public.sos_events from authenticated',
        ),
      );
      expect(sql, contains('Active family views SOS live locations'));
      expect(sql, contains('Active family views SOS events'));
      expect(
        sql,
        contains('Only the child can update an unresolved SOS location'),
      );
    }
  });

  test('defines server-authoritative family link transitions', () {
    for (final name in [
      'create_parent_child_link',
      'accept_parent_child_link',
      'reject_parent_child_link',
      'cancel_parent_child_link',
      'request_parent_child_unlink',
      'accept_parent_child_unlink',
      'reject_parent_child_unlink',
    ]) {
      expect(migration, contains('function public.$name'));
    }
    expect(migration, contains('unlink_requested_by'));
    expect(migration, contains('unlink_requested_at'));
    expect(migration, contains("status <> 'active'"));
    expect(migration, contains('Unlink request already pending'));
    expect(migration, contains('No unlink request is pending'));
    expect(migration, contains('approved the unlink request'));
    expect(migration, contains('declined the unlink request'));
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
    expect(migration, contains("status in ('open', 'acknowledged')"));
    expect(migration, contains("status = 'resolved'"));
    expect(
      migration,
      contains("where event_type = 'acknowledged' do nothing"),
    );
    expect(migration, contains("'Location unavailable'"));
  });

  test(
      'synchronizes screen time idempotently and emits every crossed threshold',
      () {
    expect(migration, contains('function public.sync_screen_time_session'));
    expect(
      migration,
      contains('on conflict (user_id, client_session_id) do nothing'),
    );
    expect(
      migration,
      contains('generate_series(3, v_total_seconds / 3600)'),
    );
    expect(migration, contains("'screen_time_threshold'"));
    expect(migration, contains('screen-time:'));
  });
}
