import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPreferenceValues {
  const NotificationPreferenceValues({
    this.inAppEnabled = true,
    this.pushEnabled = false,
    this.chatEnabled = true,
    this.activityEnabled = true,
    this.systemEnabled = true,
    this.followersEnabled = true,
  });

  final bool inAppEnabled;
  final bool pushEnabled;
  final bool chatEnabled;
  final bool activityEnabled;
  final bool systemEnabled;
  final bool followersEnabled;

  factory NotificationPreferenceValues.fromMap(Map<String, dynamic> map) {
    return NotificationPreferenceValues(
      inAppEnabled: map['in_app_enabled'] as bool? ?? true,
      pushEnabled: map['push_enabled'] as bool? ?? false,
      chatEnabled: map['chat_enabled'] as bool? ?? true,
      activityEnabled: map['activity_enabled'] as bool? ?? true,
      systemEnabled: map['system_enabled'] as bool? ?? true,
      followersEnabled: map['followers_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'in_app_enabled': inAppEnabled,
        'push_enabled': pushEnabled,
        'chat_enabled': chatEnabled,
        'activity_enabled': activityEnabled,
        'system_enabled': systemEnabled,
        'followers_enabled': followersEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class SupabaseNotificationPreferencesRepository {
  const SupabaseNotificationPreferencesRepository(this._client);

  final SupabaseClient _client;

  Future<NotificationPreferenceValues> load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const NotificationPreferenceValues();
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? const NotificationPreferenceValues()
        : NotificationPreferenceValues.fromMap(row);
  }

  Future<void> save(NotificationPreferenceValues values) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notification_preferences')
        .upsert(values.toMap(userId), onConflict: 'user_id');
  }
}
