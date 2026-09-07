import 'package:flutter/foundation.dart';

import '../domain/content_moderation.dart';
import '../domain/pending_moderation_retry.dart';

final class ModerationSubmissionCoordinator extends ChangeNotifier
    implements ContentModerationGateway {
  ModerationSubmissionCoordinator(this._gateway, this._retryStore);

  final ContentModerationGateway _gateway;
  final PendingModerationRetryStore _retryStore;

  Future<List<PendingModerationTarget>> loadPendingTargets() {
    return _retryStore.load();
  }

  @override
  Future<ContentModerationResult> moderatePost(String postId) {
    return _moderate(
      PendingModerationTarget.post(postId),
      () => _gateway.moderatePost(postId),
    );
  }

  @override
  Future<ContentModerationResult> moderateComment(String commentId) {
    return _moderate(
      PendingModerationTarget.comment(commentId),
      () => _gateway.moderateComment(commentId),
    );
  }

  Future<ContentModerationResult> retry(PendingModerationTarget target) {
    return switch (target.type) {
      PendingModerationTargetType.post => moderatePost(target.id),
      PendingModerationTargetType.comment => moderateComment(target.id),
    };
  }

  Future<ContentModerationResult> _moderate(
    PendingModerationTarget target,
    Future<ContentModerationResult> Function() request,
  ) async {
    try {
      final result = await request();
      if (result.state == ContentModerationState.failed) {
        await _retryStore.save(target);
      } else {
        await _retryStore.remove(target);
      }
      notifyListeners();
      return result;
    } on ContentModerationFailure catch (error) {
      if (error.retryAllowed) {
        await _retryStore.save(target);
      } else {
        await _retryStore.remove(target);
      }
      notifyListeners();
      rethrow;
    }
  }
}
