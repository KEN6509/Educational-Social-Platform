import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/data/shared_preferences_pending_registration_store.dart';
import 'features/auth/domain/auth_gateway.dart';
import 'features/auth/domain/pending_registration_store.dart';
import 'core/config/api_config.dart';
import 'features/posts/data/http_content_moderation_gateway.dart';
import 'features/posts/domain/content_moderation.dart';

final class AppDependencies {
  const AppDependencies({
    required this.authGateway,
    required this.pendingRegistrationStore,
    required this.contentModerationGateway,
  });

  factory AppDependencies.production(SupabaseClient client) {
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
      pendingRegistrationStore: SharedPreferencesPendingRegistrationStore(),
      contentModerationGateway: HttpContentModerationGateway(
        baseUrl: ApiConfig.baseUrl,
        accessToken: () async => client.auth.currentSession?.accessToken,
      ),
    );
  }

  final AuthGateway authGateway;
  final PendingRegistrationStore pendingRegistrationStore;
  final ContentModerationGateway contentModerationGateway;
}
