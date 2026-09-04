import 'dart:io';

import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/auth_page.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/email_otp_panel.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/registration_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_gateway.dart';
import '../../../support/fake_pending_registration_store.dart';

void main() {
  late FakeAuthGateway authGateway;
  late FakePendingRegistrationStore pendingStore;

  setUp(() {
    authGateway = FakeAuthGateway();
    pendingStore = FakePendingRegistrationStore();
    addTearDown(authGateway.dispose);
  });

  Future<void> pumpAuthPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          authGateway: authGateway,
          pendingRegistrationStore: pendingStore,
        ),
      ),
    );
  }

  testWidgets('login delegates trimmed email and password', (tester) async {
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      '  child@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Secret123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(authGateway.signInEmail, 'child@example.com');
    expect(authGateway.signInPassword, 'Secret123!');
  });

  testWidgets('registration requires consent before calling the gateway',
      (tester) async {
    await pumpAuthPage(tester);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('register-name-field')),
      '  Ming Jiang  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email-field')),
      '  ming@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'StrongPass12!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'StrongPass12!',
    );
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(authGateway.registrationRequest, isNull);
    expect(
      find.text('Accept the Terms and Privacy Policy to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('accepted registration opens OTP with normalized email',
      (tester) async {
    authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;
    await pumpAuthPage(tester);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('register-name-field')),
      '  Ming Jiang  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email-field')),
      '  MING@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'StrongPass12!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'StrongPass12!',
    );
    final consent = find.byKey(const ValueKey('registration-consent-checkbox'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.textContaining('ming@example.com'), findsOneWidget);
    expect(authGateway.registrationRequest?.name, 'Ming Jiang');
    expect(authGateway.registrationRequest?.termsVersion, '1.0');
    expect(authGateway.registrationRequest?.privacyVersion, '1.0');
    expect(find.text('Resend code in 60s'), findsOneWidget);
  });

  testWidgets('OTP verification delegates the code and clears pending email',
      (tester) async {
    authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;
    await pumpAuthPage(tester);
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
      'StrongPass12!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'StrongPass12!',
    );
    final consent = find.byKey(const ValueKey('registration-consent-checkbox'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('registration-otp-field')),
      '123456',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('registration-otp-field')),
          )
          .controller
          ?.text,
      '123456',
    );
    final verify = find.widgetWithText(FilledButton, 'Verify Email');
    await tester.ensureVisible(verify);
    expect(
      tester.widget<EmailOtpPanel>(find.byType(EmailOtpPanel)).state.phase,
      RegistrationPhase.awaitingOtp,
    );
    expect(tester.widget<FilledButton>(verify).onPressed, isNotNull);
    await tester.tap(verify);
    await tester.pumpAndSettle();

    expect(authGateway.verificationEmail, 'ming@example.com');
    expect(authGateway.verificationToken, '123456');
    expect(pendingStore.email, isNull);
  });

  testWidgets('Back from OTP preserves registration fields', (tester) async {
    authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;
    await pumpAuthPage(tester);
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
      'StrongPass12!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'StrongPass12!',
    );
    final consent = find.byKey(const ValueKey('registration-consent-checkbox'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change email'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('register-name-field')), findsOneWidget);
    expect(find.text('Ming Jiang'), findsOneWidget);
    expect(pendingStore.email, isNull);
  });

  testWidgets('unconfirmed login resumes OTP recovery', (tester) async {
    authGateway.signInError = const AuthFailure(
      'Verify your email before logging in.',
      reason: AuthFailureReason.emailNotConfirmed,
    );
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'child@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Secret123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.textContaining('child@example.com'), findsOneWidget);
    expect(find.text('Verify your email before logging in.'), findsOneWidget);
  });

  testWidgets('shows safe authentication failures', (tester) async {
    authGateway.signInError = const AuthFailure('Invalid login credentials');
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'child@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'wrong-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Invalid login credentials'), findsOneWidget);
  });

  testWidgets('shows a generic message for unexpected failures',
      (tester) async {
    authGateway.signInError = StateError('internal details');
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'child@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Secret123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal details'), findsNothing);
  });

  test('AuthPage presentation does not import or access Supabase', () {
    final source = File(
      'lib/src/features/auth/presentation/auth_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('supabase_flutter')));
    expect(source, isNot(contains('Supabase.instance')));
  });
}
