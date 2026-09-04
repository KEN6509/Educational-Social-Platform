import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class CyanZoneApp extends StatelessWidget {
  const CyanZoneApp({
    required this.dependencies,
    super.key,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyanZone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(
        authGateway: dependencies.authGateway,
        pendingRegistrationStore: dependencies.pendingRegistrationStore,
      ),
    );
  }
}
