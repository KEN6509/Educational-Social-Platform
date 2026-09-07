import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/application/moderation_submission_coordinator.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/pending_moderation_retry.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/pending_moderation_retry_banner.dart';

final class BannerRetryStore implements PendingModerationRetryStore {
  final targets = <PendingModerationTarget>[
    const PendingModerationTarget.post('post-1'),
  ];

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
  final postIds = <String>[];

  @override
  Future<ContentModerationResult> moderatePost(String postId) async {
    postIds.add(postId);
    return ContentModerationResult(
      targetId: postId,
      revision: 1,
      state: ContentModerationState.approved,
      riskScore: 5,
      reason: 'safe',
      retryAllowed: false,
    );
  }

  @override
  Future<ContentModerationResult> moderateComment(String commentId) {
    throw UnimplementedError();
  }
}

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
}
