import 'dart:async';

import 'package:cyanzone_mobile/src/features/notifications/application/push_notification_coordinator.dart';
import 'package:cyanzone_mobile/src/features/notifications/data/shared_preferences_push_state_store.dart';
import 'package:cyanzone_mobile/src/features/notifications/data/supabase_notification_preferences_repository.dart';
import 'package:cyanzone_mobile/src/features/notifications/domain/push_destination.dart';
import 'package:cyanzone_mobile/src/features/notifications/domain/push_notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGateway implements PushNotificationGateway {
  final tokenRefresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushDestination>.broadcast();
  PushAuthorizationStatus authorization = PushAuthorizationStatus.authorized;
  String? token = 'token-1';
  int foregroundShown = 0;

  @override
  Future<PushAuthorizationStatus> requestAuthorization() async => authorization;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushDestination> get onMessageOpened => opened.stream;

  @override
  Future<PushDestination?> get initialMessage async => null;

  @override
  Future<void> showForeground(PushMessage message) async => foregroundShown++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enabling registers the device before persisting push enabled',
      () async {
    final gateway = _FakeGateway();
    final store = SharedPreferencesPushStateStore();
    var registered = false;
    var savedPushValue = false;
    final coordinator = PushNotificationCoordinator(
      gateway: gateway,
      registerDevice: ({
        required deviceId,
        required token,
        required enabled,
      }) async {
        expect(enabled, true);
        registered = true;
      },
      revokeDevice: (_) async {},
      loadPreferences: () async => const NotificationPreferenceValues(),
      savePreferences: (values) async {
        expect(registered, true);
        savedPushValue = values.pushEnabled;
      },
      store: store,
      isSignedIn: () => true,
      onDestination: (_) async {},
    );

    expect(await coordinator.enablePush(), true);
    expect(savedPushValue, true);
    expect(await store.pushEnabled(), true);
  });

  test('signed-out taps are deferred until authentication', () async {
    final gateway = _FakeGateway();
    final store = SharedPreferencesPushStateStore();
    var signedIn = false;
    final opened = <PushDestination>[];
    final coordinator = PushNotificationCoordinator(
      gateway: gateway,
      registerDevice: ({
        required deviceId,
        required token,
        required enabled,
      }) async {},
      revokeDevice: (_) async {},
      loadPreferences: () async => const NotificationPreferenceValues(),
      savePreferences: (_) async {},
      store: store,
      isSignedIn: () => signedIn,
      onDestination: (destination) async => opened.add(destination),
    );
    await coordinator.onAuthenticated();
    const destination = PushDestination(
      sourceTable: 'notifications',
      sourceId: 'source-1',
      route: PushRoute.post,
      postId: 'post-1',
    );
    gateway.opened.add(destination);
    await Future<void>.delayed(Duration.zero);
    expect(await store.readPendingDestination(), isNotNull);
    signedIn = true;
    await coordinator.onAuthenticated();
    expect(opened.single.postId, 'post-1');
  });

  test('authentication restores a server-enabled device registration',
      () async {
    final gateway = _FakeGateway();
    final registeredTokens = <String>[];
    final coordinator = PushNotificationCoordinator(
      gateway: gateway,
      registerDevice: ({
        required deviceId,
        required token,
        required enabled,
      }) async {
        expect(enabled, true);
        registeredTokens.add(token);
      },
      revokeDevice: (_) async {},
      loadPreferences: () async =>
          const NotificationPreferenceValues(pushEnabled: true),
      savePreferences: (_) async {},
      store: SharedPreferencesPushStateStore(),
      isSignedIn: () => true,
      onDestination: (_) async {},
    );

    await coordinator.onAuthenticated();

    expect(registeredTokens, ['token-1']);
  });

  test('denied permission revokes an existing device registration', () async {
    final gateway = _FakeGateway()
      ..authorization = PushAuthorizationStatus.denied;
    final revokedDevices = <String>[];
    final coordinator = PushNotificationCoordinator(
      gateway: gateway,
      registerDevice: ({
        required deviceId,
        required token,
        required enabled,
      }) async {},
      revokeDevice: (deviceId) async => revokedDevices.add(deviceId),
      loadPreferences: () async => const NotificationPreferenceValues(),
      savePreferences: (_) async {},
      store: SharedPreferencesPushStateStore(),
      isSignedIn: () => true,
      onDestination: (_) async {},
    );

    expect(await coordinator.enablePush(), false);
    expect(revokedDevices, hasLength(1));
  });

  test('authentication transfers a disabled device as inactive', () async {
    final gateway = _FakeGateway();
    final activeStates = <bool>[];
    final coordinator = PushNotificationCoordinator(
      gateway: gateway,
      registerDevice: ({
        required deviceId,
        required token,
        required enabled,
      }) async {
        activeStates.add(enabled);
      },
      revokeDevice: (_) async {},
      loadPreferences: () async => const NotificationPreferenceValues(
        pushEnabled: false,
      ),
      savePreferences: (_) async {},
      store: SharedPreferencesPushStateStore(),
      isSignedIn: () => true,
      onDestination: (_) async {},
    );

    await coordinator.onAuthenticated();

    expect(activeStates, [false]);
  });
}
