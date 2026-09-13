import 'package:flutter/material.dart';

import '../../../core/widgets/app_feedback.dart';

void showDislikeFeedbackSnackBar(
  BuildContext context, {
  required VoidCallback onCancel,
  required VoidCallback onReport,
}) {
  AppFeedback.show(
    context,
    message: 'You will not see this post for 14 days.',
    showIcon: false,
    actions: [
      AppFeedbackAction(label: 'Cancel', onPressed: onCancel),
      AppFeedbackAction(label: 'Report', onPressed: onReport),
    ],
  );
}
