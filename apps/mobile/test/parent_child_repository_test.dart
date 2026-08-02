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
}
