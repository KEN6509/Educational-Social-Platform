import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/data/shared_preferences_pending_registration_store.dart';
import 'features/auth/domain/auth_gateway.dart';
import 'features/auth/domain/pending_registration_store.dart';
import 'features/posts/data/http_content_moderation_gateway.dart';
import 'features/posts/data/shared_preferences_pending_moderation_retry_store.dart';
import 'features/posts/application/moderation_submission_coordinator.dart';
import 'features/posts/domain/content_moderation.dart';
import 'features/notifications/application/push_notification_coordinator.dart';
import 'features/notifications/data/http_push_repository.dart';
import 'features/notifications/data/shared_preferences_push_state_store.dart';
import 'features/notifications/data/supabase_notification_preferences_repository.dart';
import 'features/notifications/domain/push_notification_gateway.dart';

final class AppDependencies {
  const AppDependencies({
    required this.authGateway,
    required this.pendingRegistrationStore,
    required this.contentModerationGateway,
    this.pushNotificationCoordinator,
  });

  factory AppDependencies.production(
    SupabaseClient client, {
    required Uri apiBaseUrl,
    PushNotificationGateway? pushNotificationGateway,
  }) {
    final moderationGateway = HttpContentModerationGateway(
      baseUrl: apiBaseUrl,
      accessToken: () async => client.auth.currentSession?.accessToken,
    );
    final retryStore = SharedPreferencesPendingModerationRetryStore(
      currentUserId: () => client.auth.currentUser?.id,
    );
    final pushGateway =
        pushNotificationGateway ?? const NoopPushNotificationGateway();
    final pushRepository = HttpPushRepository(
      baseUrl: apiBaseUrl,
      accessToken: () async => client.auth.currentSession?.accessToken,
    );
    final preferenceRepository =
        SupabaseNotificationPreferencesRepository(client);
    final pushCoordinator = PushNotificationCoordinator(
      gateway: pushGateway,
      registerDevice: pushRepository.registerDevice,
      revokeDevice: pushRepository.deactivateDevice,
      loadPreferences: preferenceRepository.load,
      savePreferences: preferenceRepository.save,
      store: SharedPreferencesPushStateStore(),
      isSignedIn: () => client.auth.currentUser != null,
      onDestination: (_) async {},
    );
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
      pendingRegistrationStore: SharedPreferencesPendingRegistrationStore(),
      contentModerationGateway:
          ModerationSubmissionCoordinator(moderationGateway, retryStore),
      pushNotificationCoordinator: pushCoordinator,
    );
  }

  final AuthGateway authGateway;
  final PendingRegistrationStore pendingRegistrationStore;
  final ContentModerationGateway contentModerationGateway;
  final PushNotificationCoordinator? pushNotificationCoordinator;
}
