import 'package:cyanzone_mobile/src/features/profile/presentation/set_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required PasswordReauthenticator reauthenticate,
    required PasswordUpdater updatePassword,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SetPasswordPage(
                      currentUserEmail: 'user@example.com',
                      currentUserId: 'user-1',
                      reauthenticate: reauthenticate,
                      updatePassword: updatePassword,
                    ),
                  ),
                );
              },
              child: const Text('Open password page'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open password page'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPasswords(
    WidgetTester tester, {
    required String current,
    required String password,
    required String confirm,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('current-password-field')),
      current,
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password-field')),
      password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password-field')),
      confirm,
    );
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(ElevatedButton, 'Done');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('shows current password above the new password fields',
      (tester) async {
    await pumpPage(
      tester,
      reauthenticate: (_, __) async => 'user-1',
      updatePassword: (_) async {},
    );

    final currentY = tester
        .getTopLeft(find.byKey(const ValueKey('current-password-field')))
        .dy;
    final newY =
        tester.getTopLeft(find.byKey(const ValueKey('new-password-field'))).dy;
    final confirmY = tester
        .getTopLeft(find.byKey(const ValueKey('confirm-password-field')))
        .dy;

    expect(currentY, lessThan(newY));
    expect(newY, lessThan(confirmY));
    expect(find.text('Change Password'), findsOneWidget);
  });

  testWidgets('mismatched new passwords never reauthenticate', (tester) async {
    var reauthenticationCalls = 0;
    var updateCalls = 0;
    await pumpPage(
      tester,
      reauthenticate: (_, __) async {
        reauthenticationCalls += 1;
        return 'user-1';
      },
      updatePassword: (_) async => updateCalls += 1,
    );

    await enterPasswords(
      tester,
      current: 'OldPassword12.',
      password: 'StrongPass12.',
      confirm: 'StrongPass12_',
    );
    await submit(tester);

    expect(find.text('New passwords do not match.'), findsOneWidget);
    expect(reauthenticationCalls, 0);
    expect(updateCalls, 0);
  });

  testWidgets('new password must differ from current password', (tester) async {
    var reauthenticationCalls = 0;
    await pumpPage(
      tester,
      reauthenticate: (_, __) async {
        reauthenticationCalls += 1;
        return 'user-1';
      },
      updatePassword: (_) async {},
    );

    await enterPasswords(
      tester,
      current: 'StrongPass12.',
      password: 'StrongPass12.',
      confirm: 'StrongPass12.',
    );
    await submit(tester);

    expect(
      find.text(
        'Choose a new password that differs from your current password.',
      ),
      findsOneWidget,
    );
    expect(reauthenticationCalls, 0);
  });

  testWidgets('incorrect current password prevents password update',
      (tester) async {
    var updateCalls = 0;
    await pumpPage(
      tester,
      reauthenticate: (_, __) async => 'different-user',
      updatePassword: (_) async => updateCalls += 1,
    );

    await enterPasswords(
      tester,
      current: 'WrongPassword12.',
      password: 'StrongPass12_',
      confirm: 'StrongPass12_',
    );
    await submit(tester);

    expect(find.text('Current password is incorrect.'), findsOneWidget);
    expect(updateCalls, 0);
  });

  testWidgets('verifies current password before updating', (tester) async {
    final events = <String>[];
    await pumpPage(
      tester,
      reauthenticate: (email, password) async {
        events.add('verify:$email:$password');
        return 'user-1';
      },
      updatePassword: (password) async {
        events.add('update:$password');
      },
    );

    await enterPasswords(
      tester,
      current: 'OldPassword12.',
      password: 'StrongPass12_',
      confirm: 'StrongPass12_',
    );
    await submit(tester);

    expect(
      events,
      [
        'verify:user@example.com:OldPassword12.',
        'update:StrongPass12_',
      ],
    );
    expect(find.text('Password updated successfully'), findsOneWidget);
  });

  testWidgets('shows every strong-password checklist rule', (tester) async {
    await pumpPage(
      tester,
      reauthenticate: (_, __) async => 'user-1',
      updatePassword: (_) async {},
    );

    expect(find.text('At least 12 characters'), findsOneWidget);
    expect(find.text('Contains an uppercase letter'), findsOneWidget);
    expect(find.text('Contains a lowercase letter'), findsOneWidget);
    expect(find.text('Contains a number'), findsOneWidget);
    expect(
      find.text('Contains a symbol such as !, @, #, \$, %, or &'),
      findsOneWidget,
    );
  });
}
