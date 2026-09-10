import 'package:flutter/material.dart';

class PushPermissionPrompt extends StatelessWidget {
  const PushPermissionPrompt({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PushPermissionPrompt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stay updated on CyanZone'),
      content: const Text(
        'Enable phone notifications for chat, activity, family safety, and other important updates. You can change this anytime in Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Enable'),
        ),
      ],
    );
  }
}
