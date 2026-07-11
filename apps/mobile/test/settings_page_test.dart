import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/profile/presentation/settings_page.dart';

void main() {
  testWidgets('SettingsPage notification switch persists changed value',
      (tester) async {
    Map<String, bool>? savedPreferences;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          loadNotificationPreferences: () async => const {
            'in_app_enabled': true,
            'chat_enabled': true,
            'activity_enabled': true,
            'system_enabled': true,
            'followers_enabled': true,
          },
          saveNotificationPreferences: (preferences) async {
            savedPreferences = preferences;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.widgetWithText(SwitchListTile, 'In-app notifications'));
    await tester.pump();

    expect(savedPreferences?['in_app_enabled'], isFalse);
  });
}
