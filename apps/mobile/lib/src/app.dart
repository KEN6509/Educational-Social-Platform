import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/posts/presentation/content_moderation_scope.dart';
import 'features/notifications/presentation/push_notification_scope.dart';

class CyanZoneApp extends StatelessWidget {
  const CyanZoneApp({
    required this.dependencies,
    super.key,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'CyanZone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(
        authGateway: dependencies.authGateway,
        pendingRegistrationStore: dependencies.pendingRegistrationStore,
      ),
    );
    final coordinator = dependencies.pushNotificationCoordinator;
    final withPush = coordinator == null
        ? app
        : PushNotificationScope(coordinator: coordinator, child: app);
    return ContentModerationScope(
      gateway: dependencies.contentModerationGateway,
      child: withPush,
    );
  }
}
