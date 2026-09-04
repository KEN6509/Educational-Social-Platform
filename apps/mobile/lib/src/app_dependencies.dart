import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/domain/auth_gateway.dart';

final class AppDependencies {
  const AppDependencies({required this.authGateway});

  factory AppDependencies.production(SupabaseClient client) {
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
    );
  }

  final AuthGateway authGateway;
}
