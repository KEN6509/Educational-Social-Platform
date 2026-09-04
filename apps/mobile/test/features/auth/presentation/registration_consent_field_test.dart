import 'package:cyanzone_mobile/src/features/auth/presentation/registration_consent_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('terms and privacy links open matching documents',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationConsentField(
            value: false,
            showError: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Terms and Conditions'));
    await tester.pumpAndSettle();
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.text('Version 1.0'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('How we use information'), findsOneWidget);
  });

  testWidgets('shows consent error and reports checkbox changes',
      (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationConsentField(
            value: false,
            showError: true,
            onChanged: (value) => accepted = value,
          ),
        ),
      ),
    );

    expect(
      find.text('Accept the Terms and Privacy Policy to continue.'),
      findsOneWidget,
    );
    await tester
        .tap(find.byKey(const ValueKey('registration-consent-checkbox')));
    expect(accepted, isTrue);
  });
}
