import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/push_destination.dart';
import '../domain/push_notification_gateway.dart';

abstract interface class FirebaseMessagingClient {
  Future<PushAuthorizationStatus> requestAuthorization();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onMessage;
  Stream<PushMessage> get onMessageOpenedApp;
  Future<PushMessage?> get initialMessage;
}

abstract interface class ForegroundNotificationClient {
  Future<void> initialize();
  Future<void> show(PushMessage message);
}

class FirebasePushNotificationGateway implements PushNotificationGateway {
  FirebasePushNotificationGateway({
    FirebaseMessagingClient? messaging,
    ForegroundNotificationClient? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessagingClientAdapter(),
        _localNotifications =
            localNotifications ?? FlutterForegroundNotificationClient() {
    unawaited(_localNotifications.initialize());
  }

  final FirebaseMessagingClient _messaging;
  final ForegroundNotificationClient _localNotifications;

  @override
  Future<PushAuthorizationStatus> requestAuthorization() {
    return _messaging.requestAuthorization();
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => _messaging.onMessage;

  @override
  Stream<PushDestination> get onMessageOpened => _messaging.onMessageOpenedApp
      .map((message) => PushDestination.tryParse(message.data))
      .where((destination) => destination != null)
      .cast<PushDestination>();

  @override
  Future<PushDestination?> get initialMessage async {
    final message = await _messaging.initialMessage;
    return message == null ? null : PushDestination.tryParse(message.data);
  }

  @override
  Future<void> showForeground(PushMessage message) {
    return _localNotifications.show(message);
  }
}

class FirebaseMessagingClientAdapter implements FirebaseMessagingClient {
  FirebaseMessagingClientAdapter({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<PushAuthorizationStatus> requestAuthorization() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushAuthorizationStatus.authorized,
      AuthorizationStatus.provisional => PushAuthorizationStatus.provisional,
      _ => PushAuthorizationStatus.denied,
    };
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onMessage =>
      FirebaseMessaging.onMessage.map(_mapMessage);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_mapMessage);

  @override
  Future<PushMessage?> get initialMessage async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _mapMessage(message);
  }
}

PushMessage _mapMessage(RemoteMessage message) {
  return PushMessage(
    title: message.notification?.title ?? 'CyanZone',
    body: message.notification?.body ?? 'You have a new notification.',
    data: message.data,
  );
}

class FlutterForegroundNotificationClient
    implements ForegroundNotificationClient {
  FlutterForegroundNotificationClient({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'cyanzone_default',
            'CyanZone notifications',
            description: 'Chat, activity, follower, and system notifications.',
            importance: Importance.high,
          ),
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'cyanzone_safety',
            'CyanZone safety alerts',
            description: 'Urgent parent-supervision safety notifications.',
            importance: Importance.max,
          ),
        );
  }

  @override
  Future<void> show(PushMessage message) {
    return _plugin.show(
      id: message.hashCode,
      title: message.title,
      body: message.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cyanzone_default',
          'CyanZone notifications',
          channelDescription: 'CyanZone notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
