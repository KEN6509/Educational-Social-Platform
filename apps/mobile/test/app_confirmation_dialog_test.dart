import 'dart:io';

import 'package:cyanzone_mobile/src/core/widgets/app_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all mobile confirmation flows use the shared dialog', () {
    const featureFiles = [
      'lib/src/features/profile/presentation/settings_page.dart',
      'lib/src/features/posts/presentation/create_post_page.dart',
      'lib/src/features/posts/presentation/post_detail_page.dart',
      'lib/src/features/chat/presentation/chat_room_page.dart',
      'lib/src/features/chat/presentation/chat_details_page.dart',
      'lib/src/features/chat/presentation/chat_group_pages.dart',
      'lib/src/features/chat/presentation/notification_sections_page.dart',
      'lib/src/features/chat/presentation/system_notification_detail_page.dart',
      'lib/src/features/parent_child/presentation/link_candidates_page.dart',
      'lib/src/features/parent_child/presentation/sos_page.dart',
    ];

    for (final path in featureFiles) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('AlertDialog(')), reason: path);
      expect(source, contains('showAppConfirmationDialog('), reason: path);
    }
  });

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

  testWidgets('supports a custom secondary confirmation action',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAppConfirmationDialog(
                context: context,
                icon: Icons.family_restroom_rounded,
                iconColor: const Color(0xFF4490AD),
                iconBackgroundColor: const Color(0xFFE7F4F8),
                title: 'Choose your role',
                message: 'Select your role for family linking.',
                primaryLabel: 'Child',
                secondaryLabel: 'Parent',
                primaryColor: const Color(0xFF4490AD),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    await tester.tap(find.text('Parent'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
