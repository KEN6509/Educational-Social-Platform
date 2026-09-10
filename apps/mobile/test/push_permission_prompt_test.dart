import 'package:cyanzone_mobile/src/core/widgets/app_confirmation_dialog.dart';
import 'package:cyanzone_mobile/src/features/notifications/presentation/push_permission_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the shared dialog and returns the enable decision',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await PushPermissionPrompt.show(context);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    expect(find.text('Stay updated on CyanZone'), findsOneWidget);
    expect(find.text('Enable'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
