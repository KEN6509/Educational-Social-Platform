import 'dart:io';

import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_gateway.dart';
import '../../../support/fake_pending_registration_store.dart';

void main() {
  late FakeAuthGateway authGateway;

  setUp(() {
    authGateway = FakeAuthGateway();
    addTearDown(authGateway.dispose);
  });

  Future<void> pumpAuthPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          authGateway: authGateway,
          pendingRegistrationStore: FakePendingRegistrationStore(),
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

  testWidgets('registration delegates fields and shows confirmation message',
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

    expect(authGateway.registrationName, 'Ming Jiang');
    expect(authGateway.registrationEmail, 'ming@example.com');
    expect(authGateway.registrationPassword, 'StrongPass12!');
    expect(
      find.text(
        'Account created. Check your email if confirmation is enabled.',
      ),
      findsOneWidget,
    );
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
