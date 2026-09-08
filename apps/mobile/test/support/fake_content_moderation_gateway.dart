import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';

class FakeContentModerationGateway implements ContentModerationGateway {
  @override
  Future<ContentModerationResult> moderateComment(String commentId) async {
    return ContentModerationResult(
      targetId: commentId,
      revision: 1,
      state: ContentModerationState.approved,
      riskScore: 0,
      reason: null,
      retryAllowed: false,
    );
  }

  @override
  Future<ContentModerationResult> moderatePost(String postId) async {
    return ContentModerationResult(
      targetId: postId,
      revision: 1,
      state: ContentModerationState.approved,
      riskScore: 0,
      reason: null,
      retryAllowed: false,
    );
  }
}
