import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';

abstract final class PushPermissionPrompt {
  static Future<bool?> show(BuildContext context) {
    return showAppDialog(
      context: context,
      variant: AppDialogVariant.permission,
      icon: Icons.notifications_active_outlined,
      title: 'Stay updated on CyanZone',
      message:
          'Enable phone notifications for chat, activity, family safety, and other important updates. You can change this anytime in Settings.',
      primaryLabel: 'Enable',
      secondaryLabel: 'Not now',
    );
  }
}
