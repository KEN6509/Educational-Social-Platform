import 'package:cyanzone_mobile/src/features/profile/presentation/verified_badge_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required CreatorVerificationState state,
    Future<void> Function(String statement)? submitApplication,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VerifiedBadgePage(
          loadState: () async => state,
          submitApplication: submitApplication ?? (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows requirements and submits a creator application',
      (tester) async {
    String? submittedStatement;
    await pumpPage(
      tester,
      state: const CreatorVerificationState(),
      submitApplication: (statement) async {
        submittedStatement = statement;
      },
    );

    expect(find.text('Verified Badge'), findsOneWidget);
    expect(
      find.text(
        'The verified badge helps users identify trusted content creators.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'To be eligible to submit a request for account verification:',
      ),
      findsOneWidget,
    );
    expect(find.text('Have at least 10,000 followers'), findsOneWidget);
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(
      find.text(
        'Sometimes, CyanZone may also proactively verify accounts with fewer than 10,000 followers that are well-known outside of CyanZone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Strengthen your application'), findsOneWidget);
    expect(find.text('Keep your account in good standing'), findsOneWidget);
    expect(find.text('Share valuable content'), findsOneWidget);
    expect(
        find.text('Follow the CyanZone Community Guidelines'), findsOneWidget);

    expect(find.text('Account Verification Application'), findsOneWidget);

    final statementField = tester.widget<TextField>(
      find.byKey(const ValueKey('creator-application-statement')),
    );
    expect(
      statementField.decoration?.hintText,
      'Describe your content and audience',
    );
    expect(find.text('0 / 500'), findsOneWidget);
    final counter = tester.widget<Text>(find.text('0 / 500'));
    expect(counter.textAlign, TextAlign.right);
    final fieldRight = tester
        .getRect(
          find.byKey(const ValueKey('creator-application-statement')),
        )
        .right;
    final counterRight = tester.getRect(find.text('0 / 500')).right;
    expect((fieldRight - counterRight).abs(), lessThanOrEqualTo(1));

    await tester.enterText(
      find.byKey(const ValueKey('creator-application-statement')),
      'I share original science lessons for teenagers.',
    );
    await tester
        .tap(find.widgetWithText(FilledButton, 'Apply for verification'));
    await tester.pumpAndSettle();

    expect(
      submittedStatement,
      'I share original science lessons for teenagers.',
    );
    expect(find.widgetWithText(FilledButton, 'Application pending'),
        findsOneWidget);
  });

  testWidgets(
      'rejected applications point to System notifications and can reapply',
      (tester) async {
    await pumpPage(
      tester,
      state: const CreatorVerificationState(
        requestStatus: CreatorRequestStatus.rejected,
      ),
    );

    expect(find.text('Apply again'), findsOneWidget);
    expect(
      find.text(
        'Your last request was not approved. Check System notifications for the administrator\'s reason.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('verified creators cannot submit another application',
      (tester) async {
    await pumpPage(
      tester,
      state: const CreatorVerificationState(isVerified: true),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verified creator'),
    );
    expect(button.onPressed, isNull);
    expect(find.byKey(const ValueKey('creator-application-statement')),
        findsNothing);
  });
}
