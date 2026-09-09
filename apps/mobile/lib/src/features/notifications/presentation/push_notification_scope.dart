import 'package:flutter/widgets.dart';

import '../application/push_notification_coordinator.dart';

class PushNotificationScope extends InheritedWidget {
  const PushNotificationScope({
    required this.coordinator,
    required super.child,
    super.key,
  });

  final PushNotificationCoordinator coordinator;

  static PushNotificationCoordinator? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PushNotificationScope>()
        ?.coordinator;
  }

  @override
  bool updateShouldNotify(PushNotificationScope oldWidget) =>
      coordinator != oldWidget.coordinator;
}
