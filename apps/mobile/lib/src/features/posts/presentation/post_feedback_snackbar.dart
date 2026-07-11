import 'package:flutter/material.dart';

void showDislikeFeedbackSnackBar(
  BuildContext context, {
  required VoidCallback onCancel,
  required VoidCallback onReport,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      elevation: 10,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          const Expanded(
            child: Text(
              'You will not see this post for 14 days.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentSnackBar();
              onCancel();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentSnackBar();
              onReport();
            },
            child: const Text('Report'),
          ),
        ],
      ),
    ),
  );
}
