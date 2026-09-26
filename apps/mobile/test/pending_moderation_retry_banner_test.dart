import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/application/moderation_submission_coordinator.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/pending_moderation_retry.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/pending_moderation_retry_banner.dart';

final class BannerRetryStore implements PendingModerationRetryStore {
  BannerRetryStore({List<PendingModerationTarget>? initialTargets})
      : targets = initialTargets ??
            <PendingModerationTarget>[
              const PendingModerationTarget.post('post-1'),
            ];

  final List<PendingModerationTarget> targets;

  @override
  Future<List<PendingModerationTarget>> load() async => List.of(targets);

  @override
  Future<void> remove(PendingModerationTarget target) async {
    targets.remove(target);
  }

  @override
  Future<void> save(PendingModerationTarget target) async {
    if (!targets.contains(target)) targets.add(target);
  }
}

final class BannerGateway implements ContentModerationGateway {
  BannerGateway({this.results = const {}, this.failures = const {}});

  final Map<String, ContentModerationResult> results;
  final Map<String, ContentModerationFailure> failures;
  final postIds = <String>[];
  final commentIds = <String>[];

  @override
  Future<ContentModerationResult> moderatePost(String postId) async {
    postIds.add(postId);
    return _resultFor(postId);
  }

  ContentModerationResult _resultFor(String id) {
    final failure = failures[id];
    if (failure != null) throw failure;
    if (results[id] case final result?) return result;
    return ContentModerationResult(
      targetId: id,
      revision: 1,
      state: ContentModerationState.approved,
      riskScore: 5,
      reason: 'safe',
      retryAllowed: false,
    );
  }

  @override
  Future<ContentModerationResult> moderateComment(String commentId) async {
    commentIds.add(commentId);
    return _resultFor(commentId);
  }
}

ContentModerationResult _result(
  String id,
  ContentModerationState state, {
  double? score,
  String? reason,
}) =>
    ContentModerationResult(
      targetId: id,
      revision: 1,
      state: state,
      riskScore: score,
      reason: reason,
      retryAllowed: state == ContentModerationState.failed,
    );

Widget _bannerApp(ModerationSubmissionCoordinator controller,
        {double textScale = 1}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: PendingModerationRetryBanner(controller: controller),
      ),
    );

void main() {
  testWidgets('shows persistent count and retries the same saved target id',
      (tester) async {
    final gateway = BannerGateway();
    final controller = ModerationSubmissionCoordinator(
      gateway,
      BannerRetryStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingModerationRetryBanner(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 item waiting for moderation'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);

    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    expect(gateway.postIds, ['post-1']);
    expect(find.text('1 item waiting for moderation'), findsNothing);
  });

  testWidgets(
      'retry rejection shows the full score and reason on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reason = List.filled(
            4, 'Targeted harassment was detected in the supplied content.')
        .join(' ');
    final controller = ModerationSubmissionCoordinator(
      BannerGateway(results: {
        'post-1': _result('post-1', ContentModerationState.rejected,
            score: 75, reason: reason),
      }),
      BannerRetryStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_bannerApp(controller, textScale: 1.5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('AI risk score: 75%'), findsOneWidget);
    final explanation = find.textContaining(reason);
    expect(explanation, findsOneWidget);
    expect(tester.widget<Text>(explanation).maxLines, isNull);
    expect(tester.widget<Text>(explanation).overflow,
        isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
    final scroll = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed retry outcomes retain rejection details and retry errors',
      (tester) async {
    final store = BannerRetryStore(initialTargets: [
      const PendingModerationTarget.post('post-1'),
      const PendingModerationTarget.comment('comment-1'),
      const PendingModerationTarget.comment('comment-2'),
      const PendingModerationTarget.post('post-2'),
    ]);
    final controller = ModerationSubmissionCoordinator(
      BannerGateway(
        results: {
          'post-1': _result('post-1', ContentModerationState.rejected,
              score: 85.5, reason: 'Private personal information was exposed.'),
          'comment-1': _result('comment-1', ContentModerationState.approved),
          'comment-2': _result('comment-2', ContentModerationState.adminReview),
        },
        failures: {
          'post-2': const ContentModerationFailure(
            'Moderation is temporarily unavailable. Please try again.',
            retryAllowed: true,
          ),
        },
      ),
      store,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_bannerApp(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('AI risk score: 85.5%'), findsOneWidget);
    expect(find.textContaining('Private personal information was exposed.'),
        findsOneWidget);
    expect(find.textContaining('Comment posted.'), findsOneWidget);
    expect(find.textContaining('Comment sent for administrator review.'),
        findsOneWidget);
    expect(find.textContaining('Please try again.'), findsOneWidget);
    expect(store.targets, [const PendingModerationTarget.post('post-2')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry rejection also reports a comment score and reason',
      (tester) async {
    final controller = ModerationSubmissionCoordinator(
      BannerGateway(results: {
        'comment-1': _result('comment-1', ContentModerationState.rejected,
            score: 60.01, reason: 'Targeted bullying was detected.'),
      }),
      BannerRetryStore(initialTargets: [
        const PendingModerationTarget.comment('comment-1'),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_bannerApp(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Comment was not posted.'), findsOneWidget);
    expect(find.textContaining('AI risk score: 60.01%'), findsOneWidget);
    expect(
        find.textContaining('Targeted bullying was detected.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished and changed retries do not report success',
      (tester) async {
    final store = BannerRetryStore(initialTargets: [
      const PendingModerationTarget.post('post-1'),
      const PendingModerationTarget.comment('comment-1'),
      const PendingModerationTarget.post('post-2'),
    ]);
    final controller = ModerationSubmissionCoordinator(
      BannerGateway(results: {
        'post-1': _result('post-1', ContentModerationState.processing),
        'comment-1': _result('comment-1', ContentModerationState.failed),
        'post-2': _result('post-2', ContentModerationState.superseded),
      }),
      store,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_bannerApp(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Post moderation is still processing.'),
        findsOneWidget);
    expect(find.textContaining('Comment moderation could not complete.'),
        findsOneWidget);
    expect(
        find.textContaining('Post changed. Submit the latest version again.'),
        findsOneWidget);
    expect(store.targets, [
      const PendingModerationTarget.post('post-1'),
      const PendingModerationTarget.comment('comment-1'),
    ]);
    expect(tester.takeException(), isNull);
  });
}
