import 'dart:async';

import '../data/shared_preferences_push_state_store.dart';
import '../data/supabase_notification_preferences_repository.dart';
import '../domain/push_destination.dart';
import '../domain/push_notification_gateway.dart';

typedef PushDeviceRegistrar = Future<void> Function({
  required String deviceId,
  required String token,
});
typedef PushDeviceRevoker = Future<void> Function(String deviceId);
typedef PushDestinationHandler = Future<void> Function(
    PushDestination destination);

class PushNotificationCoordinator {
  PushNotificationCoordinator({
    required this.gateway,
    required this.registerDevice,
    required this.revokeDevice,
    required this.loadPreferences,
    required this.savePreferences,
    required this.store,
    required this.isSignedIn,
    required this.onDestination,
  });

  final PushNotificationGateway gateway;
  final PushDeviceRegistrar registerDevice;
  final PushDeviceRevoker revokeDevice;
  final Future<NotificationPreferenceValues> Function() loadPreferences;
  final Future<void> Function(NotificationPreferenceValues values)
      savePreferences;
  final SharedPreferencesPushStateStore store;
  final bool Function() isSignedIn;
  final PushDestinationHandler onDestination;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<PushDestination> _destinations =
      StreamController<PushDestination>.broadcast();
  String? _deviceId;
  bool _started = false;

  Stream<PushDestination> get destinations => _destinations.stream;

  Future<void> onAuthenticated() async {
    if (!_started) {
      _started = true;
      _deviceId = await store.installationId();
      _subscriptions.add(gateway.onTokenRefresh.listen(_registerToken));
      _subscriptions.add(gateway.onForegroundMessage.listen(
        gateway.showForeground,
      ));
      _subscriptions.add(gateway.onMessageOpened.listen(_receiveDestination));
      final initial = await gateway.initialMessage;
      if (initial != null) await _receiveDestination(initial);
    }

    final pending = await store.readPendingDestination();
    if (pending != null && isSignedIn()) {
      await store.clearPendingDestination();
      await onDestination(pending);
    }
  }

  Future<bool> enablePush() async {
    final authorization = await gateway.requestAuthorization();
    if (authorization == PushAuthorizationStatus.denied) {
      await store.setPushEnabled(false);
      return false;
    }
    final token = await gateway.getToken();
    final deviceId = _deviceId ??= await store.installationId();
    if (token == null || token.trim().isEmpty) {
      await store.setPushEnabled(false);
      return false;
    }
    await registerDevice(deviceId: deviceId, token: token);
    final preferences = await loadPreferences();
    await savePreferences(_copyPreferences(preferences, pushEnabled: true));
    await store.setPushEnabled(true);
    return true;
  }

  Future<void> disablePush() async {
    final preferences = await loadPreferences();
    await savePreferences(_copyPreferences(preferences, pushEnabled: false));
    await store.setPushEnabled(false);
    final deviceId = _deviceId ?? await store.installationId();
    try {
      await revokeDevice(deviceId);
    } catch (_) {
      // The preference is already off; a future sign-in can clean up the token.
    }
  }

  Future<void> beforeSignOut() async {
    final deviceId = _deviceId ?? await store.installationId();
    try {
      await revokeDevice(deviceId);
    } catch (_) {
      // Logout must not be blocked by a temporary push API outage.
    }
    await store.setPushEnabled(false);
  }

  Future<bool> shouldShowPermissionPrompt() async {
    return !(await store.promptWasShown());
  }

  Future<void> markPermissionPromptShown() => store.markPromptShown();

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _started = false;
  }

  Future<void> _registerToken(String token) async {
    if (!await store.pushEnabled() || !isSignedIn() || token.trim().isEmpty) {
      return;
    }
    final deviceId = _deviceId ??= await store.installationId();
    try {
      await registerDevice(deviceId: deviceId, token: token);
    } catch (_) {
      // The next refresh or sign-in retries registration.
    }
  }

  Future<void> _receiveDestination(PushDestination destination) async {
    if (!isSignedIn()) {
      await store.savePendingDestination(destination);
      return;
    }
    _destinations.add(destination);
    await onDestination(destination);
  }
}

NotificationPreferenceValues _copyPreferences(
  NotificationPreferenceValues current, {
  required bool pushEnabled,
}) {
  return NotificationPreferenceValues(
    inAppEnabled: current.inAppEnabled,
    pushEnabled: pushEnabled,
    chatEnabled: current.chatEnabled,
    activityEnabled: current.activityEnabled,
    systemEnabled: current.systemEnabled,
    followersEnabled: current.followersEnabled,
  );
}
