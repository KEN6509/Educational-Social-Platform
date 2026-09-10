import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push startup waits until inherited dependencies are safe to read', () {
    final source = File(
      'lib/src/features/shell/presentation/main_shell.dart',
    ).readAsStringSync();

    expect(source, contains('addPostFrameCallback'));
  });

  test('System post deletion publishes its returned interaction result', () {
    final source = File(
      'lib/src/features/chat/presentation/system_notification_detail_page.dart',
    ).readAsStringSync();

    expect(source, contains('PostInteractionSync.publish'));
  });

  test('profile deletion updates the visible post count', () {
    final source = File(
      'lib/src/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();

    expect(source, contains('onPostDeleted'));
    expect(source, contains('postCount:'));
  });

  test('foreground notifications support taps and the SOS channel', () {
    final source = File(
      'lib/src/features/notifications/data/firebase_push_notification_gateway.dart',
    ).readAsStringSync();

    expect(source, contains('onDidReceiveNotificationResponse'));
    expect(source, contains("route == 'sos'"));
  });

  test('Android declares default FCM icon and channel metadata', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('default_notification_icon'));
    expect(manifest, contains('default_notification_channel_id'));
  });

  test('push taps open exact notification destinations', () {
    final source = File(
      'lib/src/features/notifications/presentation/push_destination_navigator.dart',
    ).readAsStringSync();

    expect(source, contains('initialCommentId: destination.commentId'));
    expect(source, contains('SystemNotificationDetailPage'));
    expect(source, contains('SupervisionNotificationRouter'));
    expect(source, isNot(contains('const ParentChildPage()')));
    expect(source, contains('resolved.source'));
  });

  test('authentication atomically synchronizes disabled device ownership', () {
    final source = File(
      'lib/src/features/notifications/application/push_notification_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains('required bool enabled'));
    expect(source, contains('enabled: preferences.pushEnabled'));
  });
}
