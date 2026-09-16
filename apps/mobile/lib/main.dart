import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/app_dependencies.dart';
import 'src/bootstrap/cyanzone_startup_error_page.dart';
import 'src/core/config/api_config.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/config/supabase_config.dart';
import 'src/features/notifications/data/firebase_push_notification_gateway.dart';

@pragma('vm:entry-point')
Future<void> cyanZoneFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runProductionApp();
}

Future<void> _runProductionApp() async {
  try {
    final dependencies = await _initializeProductionApp();
    runApp(CyanZoneApp(dependencies: dependencies));
  } catch (_) {
    runApp(
      MaterialApp(
        title: 'CyanZone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: CyanZoneStartupErrorPage(
          onRetry: _runProductionApp,
        ),
      ),
    );
  }
}

Future<AppDependencies> _initializeProductionApp() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await dotenv.load();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
    cyanZoneFirebaseMessagingBackgroundHandler,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  return AppDependencies.production(
    Supabase.instance.client,
    apiBaseUrl: ApiConfig.baseUrl,
    pushNotificationGateway: FirebasePushNotificationGateway(),
  );
}
