import 'dart:async';

import 'package:cyanzone_mobile/src/features/profile/presentation/set_password_page.dart';
import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/core/widgets/password_checklist.dart';
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
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, AppColors.surface);
    expect(snackBar.shape, isA<RoundedRectangleBorder>());
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

  testWidgets('failed password update keeps the page available',
      (tester) async {
    await pumpPage(
      tester,
      reauthenticate: (_, __) async => 'user-1',
      updatePassword: (_) async => throw StateError('update failed'),
    );

    await enterPasswords(
      tester,
      current: 'OldPassword12.',
      password: 'StrongPass12_',
      confirm: 'StrongPass12_',
    );
    await submit(tester);

    expect(
      find.text('Could not update password. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Change Password'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('processing disables duplicate password submission',
      (tester) async {
    final verification = Completer<String?>();
    var reauthenticationCalls = 0;

    await pumpPage(
      tester,
      reauthenticate: (_, __) {
        reauthenticationCalls += 1;
        return verification.future;
      },
      updatePassword: (_) async {},
    );

    await enterPasswords(
      tester,
      current: 'OldPassword12.',
      password: 'StrongPass12_',
      confirm: 'StrongPass12_',
    );
    final submitButton = find.widgetWithText(ElevatedButton, 'Done');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(reauthenticationCalls, 1);
    final processingButton =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(processingButton.onPressed, isNull);

    verification.complete('different-user');
    await tester.pumpAndSettle();

    expect(reauthenticationCalls, 1);
  });

  testWidgets('leaving during reauthentication cancels the password update',
      (tester) async {
    final verification = Completer<String?>();
    var updateCalls = 0;

    await pumpPage(
      tester,
      reauthenticate: (_, __) => verification.future,
      updatePassword: (_) async => updateCalls += 1,
    );

    await enterPasswords(
      tester,
      current: 'OldPassword12.',
      password: 'StrongPass12_',
      confirm: 'StrongPass12_',
    );
    final submitButton = find.widgetWithText(ElevatedButton, 'Done');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    verification.complete('user-1');
    await tester.pumpAndSettle();

    expect(updateCalls, 0);
  });

  testWidgets('preserves ten pixel gap before password guidance',
      (tester) async {
    await pumpPage(
      tester,
      reauthenticate: (_, __) async => 'user-1',
      updatePassword: (_) async {},
    );

    final checklistBottom =
        tester.getBottomLeft(find.byType(PasswordChecklist)).dy;
    final guidanceTop = tester
        .getTopLeft(
          find.text(
            'Your new password must be different from your current password.',
          ),
        )
        .dy;

    expect(guidanceTop - checklistBottom, 10);
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
