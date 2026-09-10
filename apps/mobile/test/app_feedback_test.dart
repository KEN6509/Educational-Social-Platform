import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/core/theme/app_theme.dart';
import 'package:cyanzone_mobile/src/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the white floating error feedback surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppFeedback.showError(context, 'Unable to save'),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackbar.behavior, SnackBarBehavior.floating);
    expect(snackbar.backgroundColor, AppColors.surface);
    expect(snackbar.duration, const Duration(seconds: 4));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Unable to save'), findsOneWidget);
  });

  testWidgets('runs an action and uses the extended duration', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppFeedback.show(
                context,
                message: 'Moderation could not complete.',
                kind: AppFeedbackKind.warning,
                actions: [
                  AppFeedbackAction(
                    label: 'Retry',
                    onPressed: () => retried = true,
                  ),
                ],
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackbar.duration, const Duration(seconds: 6));
    final retryButton = find.ancestor(
      of: find.text('Retry'),
      matching: find.byType(TextButton),
    );
    tester.widget<TextButton>(retryButton).onPressed!();
    expect(retried, isTrue);
  });

  testWidgets('two long actions do not overflow on a compact scaled screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppFeedback.show(
                  context,
                  message: 'This item will be hidden from your feed.',
                  kind: AppFeedbackKind.warning,
                  actions: [
                    AppFeedbackAction(
                      label: 'Cancel this action',
                      onPressed: () {},
                    ),
                    AppFeedbackAction(
                      label: 'Report inappropriate content',
                      onPressed: () {},
                    ),
                  ],
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel this action'), findsOneWidget);
    expect(find.text('Report inappropriate content'), findsOneWidget);
  });
}
