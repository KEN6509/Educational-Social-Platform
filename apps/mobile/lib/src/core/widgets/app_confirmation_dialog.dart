import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

enum AppDialogVariant { information, confirmation, destructive, permission }

Future<bool?> showAppDialog({
  required BuildContext context,
  required AppDialogVariant variant,
  required IconData icon,
  required String title,
  required String message,
  required String primaryLabel,
  String? secondaryLabel,
  Key? primaryKey,
  Key? secondaryKey,
}) {
  final destructive = variant == AppDialogVariant.destructive;
  final information = variant == AppDialogVariant.information;

  return showDialog<bool>(
    context: context,
    barrierDismissible: information,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => AppConfirmationDialog(
      icon: icon,
      iconColor: destructive ? AppColors.error : AppColors.cyan,
      iconBackgroundColor:
          destructive ? const Color(0xFFFFE4E6) : const Color(0xFFE7F4F8),
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: destructive ? AppColors.error : AppColors.navy,
      secondaryLabel: secondaryLabel,
      primaryKey: primaryKey,
      cancelKey: secondaryKey,
    ),
  );
}

Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required Color iconBackgroundColor,
  required String title,
  required String message,
  required String primaryLabel,
  required Color primaryColor,
  String secondaryLabel = 'Cancel',
  Key? primaryKey,
  Key? cancelKey,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => AppConfirmationDialog(
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: primaryColor,
      secondaryLabel: secondaryLabel,
      primaryKey: primaryKey,
      cancelKey: cancelKey,
    ),
  );
}

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryColor,
    this.secondaryLabel = 'Cancel',
    this.primaryKey,
    this.cancelKey,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String message;
  final String primaryLabel;
  final Color primaryColor;
  final String? secondaryLabel;
  final Key? primaryKey;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: primaryKey,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.compact),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel case final label?) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  key: cancelKey,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
