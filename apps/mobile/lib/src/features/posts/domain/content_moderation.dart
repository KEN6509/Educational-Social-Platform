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

String moderationRejectionMessage({
  required String subject,
  required double? riskScore,
  required String? reason,
}) {
  final parts = <String>[_asSentence(subject.trim())];
  if (riskScore != null) {
    parts.add('AI risk score: ${_formatRiskScore(riskScore)}%.');
  }
  final explanation = reason?.trim();
  if (explanation != null && explanation.isNotEmpty) {
    parts.add('Reason: ${_asSentence(explanation)}');
  }
  return parts.join(' ');
}

String _formatRiskScore(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _asSentence(String value) {
  if (value.isEmpty) return value;
  return RegExp(r'[.!?]$').hasMatch(value) ? value : '$value.';
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
