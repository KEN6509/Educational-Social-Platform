import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../domain/content_moderation.dart';
import '../domain/pending_moderation_retry.dart';

Future<void> showModerationResultDetails(
  BuildContext context, {
  required String message,
  String title = 'Moderation result',
  bool balancedInformationSpacing = false,
}) async {
  await showAppDialog(
    context: context,
    variant: AppDialogVariant.information,
    icon: Icons.policy_outlined,
    title: title,
    message: message,
    primaryLabel: 'OK',
    balancedInformationSpacing: balancedInformationSpacing,
  );
}

String moderationRetryOutcomeMessage({
  required PendingModerationTargetType type,
  required ContentModerationResult result,
}) {
  final subject = type == PendingModerationTargetType.post ? 'Post' : 'Comment';
  return switch (result.state) {
    ContentModerationState.approved => type == PendingModerationTargetType.post
        ? 'Post published.'
        : 'Comment posted.',
    ContentModerationState.adminReview =>
      '$subject sent for administrator review.',
    ContentModerationState.processing =>
      '$subject moderation is still processing.',
    ContentModerationState.rejected => moderationRejectionMessage(
        subject: type == PendingModerationTargetType.post
            ? 'Post was not published'
            : 'Comment was not posted',
        riskScore: result.riskScore,
        reason: result.reason,
      ),
    ContentModerationState.failed =>
      '$subject moderation could not complete. Please try again.',
    ContentModerationState.superseded =>
      '$subject changed. Submit the latest version again.',
  };
}
