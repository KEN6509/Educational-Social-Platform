import 'dart:io';

import 'package:cyanzone_mobile/src/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed post moderation points to Home retry without snackbar action',
      () {
    final source = File(
      'lib/src/features/posts/presentation/create_post_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('void _showModerationRetry(');
    final end = source.indexOf('void _showSubmissionError(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final feedback = source.substring(start, end);

    expect(
      feedback,
      contains(
          "AI moderation couldn't complete. Retry after 15 seconds on the Home page."),
    );
    expect(feedback, isNot(contains('Retry moderation')));
    expect(feedback, isNot(contains('AppFeedbackAction(')));
  });

  test('successful post deletion shows feedback after removal', () {
    final source = File(
      'lib/src/features/posts/presentation/post_detail_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _deletePost()');
    final end = source.indexOf('Future<bool?> _showPostDecisionDialog(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final deletePost = source.substring(start, end);

    final remove = deletePost.indexOf('await repo.removePost(_post.id);');
    final success = deletePost.indexOf(
      "AppFeedback.showSuccess(context, 'Post deleted successfully.');",
    );
    final pop = deletePost.indexOf("navigator.pop({'deleted': true});");
    expect(remove, greaterThanOrEqualTo(0));
    expect(success, greaterThan(remove));
    expect(pop, greaterThan(success));
  });

  testWidgets(
      'success feedback remains visible after returning from post detail',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Builder(builder: (detailContext) {
                  return TextButton(
                    onPressed: () {
                      AppFeedback.showSuccess(
                        detailContext,
                        'Post deleted successfully.',
                      );
                      Navigator.of(detailContext).pop();
                    },
                    child: const Text('Delete post'),
                  );
                }),
              ),
            )),
            child: const Text('Open post'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete post'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Open post'), findsOneWidget);
    expect(find.text('Post deleted successfully.'), findsWidgets);
  });
}
