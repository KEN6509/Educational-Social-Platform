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
      find.text('Enter your password.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(
      find.text('Enter your password.'),
      findsNothing,
    );
    expect(find.text('Enter your name.'), findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final loginMode = find.ancestor(
      of: find.text('Log in').first,
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(loginMode);
    await tester.pumpAndSettle();
    await tester.tap(loginMode);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(
      find.text('Enter your password.'),
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

  testWidgets('registration enforces the strong password policy',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CyanZoneApp());
    await tester.pump();

    await tester.tap(find.text('Create account'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('register-name-field')),
      'Ming Jiang',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email-field')),
      'ming@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'weakpassword',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'weakpassword',
    );

    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(
      find.text(
        'Use at least 12 characters with uppercase, lowercase, a number, '
        'and a symbol such as !, @, #, \$, %, or &.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('registration shows and updates the live password checklist',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CyanZoneApp());
    await tester.pump();

    expect(find.text('At least 12 characters'), findsNothing);

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('At least 12 characters'), findsOneWidget);
    expect(find.text('Contains an uppercase letter'), findsOneWidget);
    expect(find.text('Contains a lowercase letter'), findsOneWidget);
    expect(find.text('Contains a number'), findsOneWidget);
    expect(
      find.text('Contains a symbol such as !, @, #, \$, %, or &'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'StrongPass12!',
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final loginMode = find.ancestor(
      of: find.text('Log in').first,
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(loginMode);
    await tester.pumpAndSettle();
    await tester.tap(loginMode);
    await tester.pump();

    expect(find.text('At least 12 characters'), findsNothing);
  });
}
