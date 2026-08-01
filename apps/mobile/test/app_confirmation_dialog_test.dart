import 'package:cyanzone_mobile/src/core/widgets/app_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp({required ValueChanged<bool?> onResult}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showAppConfirmationDialog(
                  context: context,
                  icon: Icons.delete_outline_rounded,
                  iconColor: Colors.red,
                  iconBackgroundColor: const Color(0xFFFEE2E2),
                  title: 'Delete post?',
                  message: 'This action cannot be undone.',
                  primaryLabel: 'Delete',
                  primaryColor: Colors.red,
                  primaryKey: const Key('confirm-delete'),
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the shared confirmation design and cancels',
      (tester) async {
    bool? result;
    await tester.pumpWidget(testApp(onResult: (value) => result = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.text('Delete post?'), findsOneWidget);
    expect(find.text('This action cannot be undone.'), findsOneWidget);
    expect(find.byKey(const Key('confirm-delete')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('returns true from the primary action', (tester) async {
    bool? result;
    await tester.pumpWidget(testApp(onResult: (value) => result = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
