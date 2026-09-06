import 'package:cyanzone_mobile/src/features/auth/presentation/registration_consent_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one inline legal link opens both registration documents',
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

    final agreementText = tester.widget<Text>(
      find.byKey(const ValueKey('registration-consent-text')),
    );
    final rootSpan = agreementText.textSpan! as TextSpan;
    final linkSpans = rootSpan.children!
        .whereType<TextSpan>()
        .where((span) => span.recognizer is TapGestureRecognizer)
        .toList();

    expect(linkSpans, hasLength(1));
    expect(
      linkSpans.single.text,
      'Terms and Conditions and Privacy Policy',
    );

    (linkSpans.single.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Terms and Privacy Policy'), findsOneWidget);
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.text('Using CyanZone'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Privacy Policy'), 400);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('How we use information'), 400);
    expect(find.text('How we use information'), findsOneWidget);
  });

  testWidgets('checkbox and agreement text share one centered row',
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

    final consentRow = tester.widget<Row>(
      find
          .descendant(
            of: find.byType(RegistrationConsentField),
            matching: find.byType(Row),
          )
          .first,
    );

    expect(consentRow.crossAxisAlignment, CrossAxisAlignment.center);
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
