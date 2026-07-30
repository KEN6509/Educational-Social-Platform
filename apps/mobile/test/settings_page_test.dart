import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/profile/presentation/settings_page.dart';

void main() {
  Future<void> pumpSettings(
    WidgetTester tester, {
    required Future<void> Function() signOut,
  }) async {
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
          saveNotificationPreferences: (_) async {},
          signOut: signOut,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logout = find.text('Log out');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
  }

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

  testWidgets('cancelling logout keeps the session active', (tester) async {
    var signOutCalls = 0;
    await pumpSettings(
      tester,
      signOut: () async => signOutCalls += 1,
    );

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to log out of CyanZone?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(signOutCalls, 0);
    expect(find.text('Log out?'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('confirming logout signs out exactly once', (tester) async {
    var signOutCalls = 0;
    await pumpSettings(
      tester,
      signOut: () async => signOutCalls += 1,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Log out'),
      ),
    );
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
  });

  testWidgets('failed logout keeps Settings open and shows an error',
      (tester) async {
    await pumpSettings(
      tester,
      signOut: () async => throw Exception('network unavailable'),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Log out'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.text('Could not log out. Please try again.'),
      findsOneWidget,
    );
  });
}
