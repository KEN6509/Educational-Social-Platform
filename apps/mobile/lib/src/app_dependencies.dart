import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/data/shared_preferences_pending_registration_store.dart';
import 'features/auth/domain/auth_gateway.dart';
import 'features/auth/domain/pending_registration_store.dart';

final class AppDependencies {
  const AppDependencies({
    required this.authGateway,
    required this.pendingRegistrationStore,
  });

  factory AppDependencies.production(SupabaseClient client) {
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
      pendingRegistrationStore: SharedPreferencesPendingRegistrationStore(),
    );
  }

  final AuthGateway authGateway;
  final PendingRegistrationStore pendingRegistrationStore;
}
