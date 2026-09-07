import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/data/shared_preferences_pending_registration_store.dart';
import 'features/auth/domain/auth_gateway.dart';
import 'features/auth/domain/pending_registration_store.dart';
import 'features/posts/data/http_content_moderation_gateway.dart';
import 'features/posts/data/shared_preferences_pending_moderation_retry_store.dart';
import 'features/posts/application/moderation_submission_coordinator.dart';
import 'features/posts/domain/content_moderation.dart';

final class AppDependencies {
  const AppDependencies({
    required this.authGateway,
    required this.pendingRegistrationStore,
    required this.contentModerationGateway,
  });

  factory AppDependencies.production(
    SupabaseClient client, {
    required Uri apiBaseUrl,
  }) {
    final moderationGateway = HttpContentModerationGateway(
      baseUrl: apiBaseUrl,
      accessToken: () async => client.auth.currentSession?.accessToken,
    );
    final retryStore = SharedPreferencesPendingModerationRetryStore(
      currentUserId: () => client.auth.currentUser?.id,
    );
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
      pendingRegistrationStore: SharedPreferencesPendingRegistrationStore(),
      contentModerationGateway:
          ModerationSubmissionCoordinator(moderationGateway, retryStore),
    );
  }

  final AuthGateway authGateway;
  final PendingRegistrationStore pendingRegistrationStore;
  final ContentModerationGateway contentModerationGateway;
}
