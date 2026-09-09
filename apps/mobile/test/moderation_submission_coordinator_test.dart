import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/application/moderation_submission_coordinator.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/pending_moderation_retry.dart';

final class FakeRetryStore implements PendingModerationRetryStore {
  final targets = <PendingModerationTarget>[];

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

final class FakeModerationGateway implements ContentModerationGateway {
  Object? postOutcome;
  Object? commentOutcome;
  final postIds = <String>[];
  final commentIds = <String>[];

  @override
  Future<ContentModerationResult> moderatePost(String postId) async {
    postIds.add(postId);
    return _resolve(postOutcome);
  }

  @override
  Future<ContentModerationResult> moderateComment(String commentId) async {
    commentIds.add(commentId);
    return _resolve(commentOutcome);
  }

  ContentModerationResult _resolve(Object? outcome) {
    if (outcome is Exception) throw outcome;
    return outcome! as ContentModerationResult;
  }
}

ContentModerationResult result(
  String targetId,
  ContentModerationState state,
) {
  return ContentModerationResult(
    targetId: targetId,
    revision: 1,
    state: state,
    riskScore: null,
    reason: null,
    retryAllowed: state == ContentModerationState.failed,
  );
}

void main() {
  test('retryable failure stores the original post id for later retry',
      () async {
    final gateway = FakeModerationGateway()
      ..postOutcome = const ContentModerationFailure(
        'offline',
        retryAllowed: true,
      );
    final store = FakeRetryStore();
    final coordinator = ModerationSubmissionCoordinator(gateway, store);

    await expectLater(
      coordinator.moderatePost('post-1'),
      throwsA(isA<ContentModerationFailure>()),
    );

    expect(store.targets, [const PendingModerationTarget.post('post-1')]);
    expect(gateway.postIds, ['post-1']);
  });

  test('retry uses the same comment id and clears it after admin review',
      () async {
    final gateway = FakeModerationGateway()
      ..commentOutcome = result(
        'comment-1',
        ContentModerationState.adminReview,
      );
    final store = FakeRetryStore()
      ..targets.add(const PendingModerationTarget.comment('comment-1'));
    final coordinator = ModerationSubmissionCoordinator(gateway, store);

    final response = await coordinator.retry(
      const PendingModerationTarget.comment('comment-1'),
    );

    expect(response.state, ContentModerationState.adminReview);
    expect(gateway.commentIds, ['comment-1']);
    expect(store.targets, isEmpty);
  });

  test('failed response remains pending while rejected response is terminal',
      () async {
    final gateway = FakeModerationGateway()
      ..postOutcome = result('post-1', ContentModerationState.failed);
    final store = FakeRetryStore();
    final coordinator = ModerationSubmissionCoordinator(gateway, store);

    await coordinator.moderatePost('post-1');
    expect(store.targets, [const PendingModerationTarget.post('post-1')]);

    gateway.postOutcome = result('post-1', ContentModerationState.rejected);
    await coordinator.retry(const PendingModerationTarget.post('post-1'));
    expect(store.targets, isEmpty);
  });

  test('processing response stays in the retry queue until it is terminal',
      () async {
    final gateway = FakeModerationGateway()
      ..postOutcome = result('post-1', ContentModerationState.processing);
    final store = FakeRetryStore();
    final coordinator = ModerationSubmissionCoordinator(gateway, store);

    await coordinator.moderatePost('post-1');

    expect(store.targets, [const PendingModerationTarget.post('post-1')]);
  });
}
