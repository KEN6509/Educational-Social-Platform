import 'dart:async';

import 'package:cyanzone_mobile/src/features/notifications/data/firebase_push_notification_gateway.dart';
import 'package:cyanzone_mobile/src/features/notifications/domain/push_destination.dart';
import 'package:cyanzone_mobile/src/features/notifications/domain/push_notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessaging implements FirebaseMessagingClient {
  final tokenRefresh = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  PushAuthorizationStatus authorization = PushAuthorizationStatus.denied;
  String? token = 'fcm-token';
  PushMessage? initial;

  @override
  Future<PushAuthorizationStatus> requestAuthorization() async => authorization;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<PushMessage> get onMessage => messages.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;

  @override
  Future<PushMessage?> get initialMessage async => initial;
}

class _FakeLocalNotifications implements ForegroundNotificationClient {
  final shown = <PushMessage>[];
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> show(PushMessage message) async => shown.add(message);
}

void main() {
  test('gateway forwards authorization, token, foreground, and tap events',
      () async {
    final messaging = _FakeMessaging()
      ..authorization = PushAuthorizationStatus.authorized;
    final local = _FakeLocalNotifications();
    final gateway = FirebasePushNotificationGateway(
      messaging: messaging,
      localNotifications: local,
    );
    await Future<void>.delayed(Duration.zero);

    expect(await gateway.requestAuthorization(),
        PushAuthorizationStatus.authorized);
    expect(await gateway.getToken(), 'fcm-token');
    expect(local.initialized, true);

    final opened = gateway.onMessageOpened.first;
    messaging.opened.add(const PushMessage(
      title: 'Chat',
      body: 'Hello',
      data: {
        'version': '1',
        'sourceTable': 'notifications',
        'sourceId': 'source-1',
        'route': 'conversation',
        'conversationId': 'conversation-1',
      },
    ));
    expect((await opened).route, PushRoute.conversation);

    const foreground = PushMessage(title: 'Title', body: 'Body', data: {});
    await gateway.showForeground(foreground);
    expect(local.shown.single, foreground);

    await messaging.tokenRefresh.close();
    await messaging.messages.close();
    await messaging.opened.close();
  });

  test('malformed taps are ignored', () async {
    final messaging = _FakeMessaging();
    final gateway = FirebasePushNotificationGateway(
      messaging: messaging,
      localNotifications: _FakeLocalNotifications(),
    );
    final events = <PushDestination>[];
    final subscription = gateway.onMessageOpened.listen(events.add);
    messaging.opened.add(const PushMessage(
      title: 'Unknown',
      body: 'Unknown',
      data: {'version': '2'},
    ));
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    await subscription.cancel();
    await messaging.opened.close();
  });
}
