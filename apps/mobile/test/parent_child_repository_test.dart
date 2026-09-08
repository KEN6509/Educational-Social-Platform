import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sensitive mutations use only approved RPCs', () {
    final source = File(
      'lib/src/features/parent_child/data/parent_child_repository.dart',
    ).readAsStringSync();

    for (final rpc in [
      'create_parent_child_link',
      'accept_parent_child_link',
      'reject_parent_child_link',
      'cancel_parent_child_link',
      'submit_safety_check_in',
      'submit_sos_alert',
      'acknowledge_sos_alert',
      'resolve_sos_alert',
      'sync_screen_time_session',
      'mark_supervision_notification_read',
    ]) {
      expect(source, contains("'$rpc'"));
    }

    expect(source, isNot(contains('createInvite(')));
    expect(source, isNot(contains('updateLinkStatus(')));
    expect(source, contains('.limit(10)'));
  });

  test('repository exposes candidate, dashboard, records, and realtime reads',
      () {
    final source = File(
      'lib/src/features/parent_child/data/parent_child_repository.dart',
    ).readAsStringSync();

    expect(source, contains('fetchDashboard'));
    expect(source, contains('fetchLinkCandidates'));
    expect(source, contains('fetchCheckIns'));
    expect(source, contains('fetchSosAlerts'));
    expect(source, contains('subscribeToSupervisionChanges'));
    expect(source, contains(".from('supervision_notifications')"));
    expect(source, contains(".from('follows')"));
  });

  test('candidate reads merge pending and active family link states', () {
    final source = File(
      'lib/src/features/parent_child/data/parent_child_repository.dart',
    ).readAsStringSync();

    expect(source, contains('final links = await fetchLinks();'));
    expect(source, contains('LinkCandidateState.pending'));
    expect(source, contains('LinkCandidateState.linked'));
  });

  test('repository exposes focused live SOS reads, writes, and realtime', () {
    final source = File(
      'lib/src/features/parent_child/data/parent_child_repository.dart',
    ).readAsStringSync();

    for (final method in [
      'fetchActiveSos',
      'fetchSosDetail',
      'updateSosLocation',
      'subscribeToSosDetailChanges',
    ]) {
      expect(source, contains(method));
    }
    expect(source, contains("'fetch_active_sos_alert'"));
    expect(source, contains("'update_sos_live_location'"));
    expect(source, contains(".from('sos_live_locations')"));
    expect(source, contains(".from('sos_events')"));
    for (final parameter in [
      "'p_sos_id'",
      "'p_latitude'",
      "'p_longitude'",
      "'p_accuracy_meters'",
      "'p_location_captured_at'",
    ]) {
      expect(source, contains(parameter));
    }
    expect(source, contains("table: 'sos_live_locations'"));
    expect(source, contains("table: 'sos_events'"));
  });
}
