import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cyanzone_mobile/src/app.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('shows the auth screen when signed out',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CyanZoneApp());
    await tester.pump();

    expect(find.text('CyanZone'), findsOneWidget);
    expect(
      find.text('Beyond the Blue, Inside the Zone.'),
      findsOneWidget,
    );
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.bySemanticsLabel('CyanZone logo'), findsOneWidget);
  });

  testWidgets('clears validation errors when switching auth modes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CyanZoneApp());
    await tester.pump();

    await tester.tap(find.text('Log in').last);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(
      find.text('Password must be at least 8 characters.'),
      findsNothing,
    );
    expect(find.text('Enter your name.'), findsNothing);

    await tester.tap(find.text('Log in').first);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(
      find.text('Password must be at least 8 characters.'),
      findsNothing,
    );
  });

  testWidgets('dismisses focused auth input when tapping empty space',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CyanZoneApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('login-email-field')));
    await tester.pump();

    final emailInput = find.descendant(
      of: find.byKey(const ValueKey('login-email-field')),
      matching: find.byType(EditableText),
    );

    expect(tester.widget<EditableText>(emailInput).focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(12, 12));
    await tester.pump();

    expect(tester.widget<EditableText>(emailInput).focusNode.hasFocus, isFalse);
  });
}
