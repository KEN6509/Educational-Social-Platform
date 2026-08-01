import 'package:flutter/material.dart';

Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required Color iconBackgroundColor,
  required String title,
  required String message,
  required String primaryLabel,
  required Color primaryColor,
  Key? primaryKey,
  Key? cancelKey,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => AppConfirmationDialog(
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: primaryColor,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GestureDetector(
                key: primaryKey,
                onTap: () => Navigator.of(context).pop(true),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: GestureDetector(
                key: cancelKey,
                onTap: () => Navigator.of(context).pop(false),
                behavior: HitTestBehavior.opaque,
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
