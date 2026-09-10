import 'package:cyanzone_mobile/src/features/notifications/data/supabase_notification_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preference parsing keeps push independent from in-app settings', () {
    final values = NotificationPreferenceValues.fromMap({
      'in_app_enabled': false,
      'push_enabled': true,
      'chat_enabled': false,
    });

    expect(values.inAppEnabled, false);
    expect(values.pushEnabled, true);
    expect(values.chatEnabled, false);
    expect(values.activityEnabled, true);
  });
}
