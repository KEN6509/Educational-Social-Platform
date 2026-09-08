enum ContentModerationState {
  processing,
  adminReview,
  approved,
  rejected,
  failed,
  superseded,
}

final class ContentModerationResult {
  const ContentModerationResult({
    required this.targetId,
    required this.revision,
    required this.state,
    required this.riskScore,
    required this.reason,
    required this.retryAllowed,
  });

  final String targetId;
  final int revision;
  final ContentModerationState state;
  final double? riskScore;
  final String? reason;
  final bool retryAllowed;
}

abstract interface class ContentModerationGateway {
  Future<ContentModerationResult> moderatePost(String postId);

  Future<ContentModerationResult> moderateComment(String commentId);
}

final class ContentModerationFailure implements Exception {
  const ContentModerationFailure(
    this.message, {
    this.retryAllowed = false,
    this.statusCode,
  });

  final String message;
  final bool retryAllowed;
  final int? statusCode;

  @override
  String toString() => message;
}
