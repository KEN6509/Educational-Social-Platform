import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/app_dependencies.dart';
import 'src/core/config/api_config.dart';
import 'src/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await dotenv.load();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final dependencies = AppDependencies.production(
    Supabase.instance.client,
    apiBaseUrl: ApiConfig.baseUrl,
  );
  runApp(CyanZoneApp(dependencies: dependencies));
}
