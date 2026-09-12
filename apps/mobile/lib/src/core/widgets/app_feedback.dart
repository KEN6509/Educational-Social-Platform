import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

enum AppFeedbackKind { neutral, success, warning, error }

class AppFeedbackAction {
  const AppFeedbackAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

abstract final class AppFeedback {
  static void show(
    BuildContext context, {
    required String message,
    AppFeedbackKind kind = AppFeedbackKind.neutral,
    List<AppFeedbackAction> actions = const [],
    bool showIcon = true,
  }) {
    assert(actions.length <= 2, 'App feedback supports at most two actions.');
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          elevation: 10,
          margin: AppInsets.snackbar,
          duration: Duration(seconds: actions.isEmpty ? 4 : 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.compact),
            side: const BorderSide(color: AppColors.border),
          ),
          content: _FeedbackContent(
            message: message,
            kind: kind,
            actions: actions,
            showIcon: showIcon,
            onActionPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, kind: AppFeedbackKind.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, kind: AppFeedbackKind.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, kind: AppFeedbackKind.warning);
  }
}

class _FeedbackContent extends StatelessWidget {
  const _FeedbackContent({
    required this.message,
    required this.kind,
    required this.actions,
    required this.showIcon,
    required this.onActionPressed,
  });

  final String message;
  final AppFeedbackKind kind;
  final List<AppFeedbackAction> actions;
  final bool showIcon;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      message,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
    final children = <Widget>[];
    if (showIcon) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Icon(_iconFor(kind), color: _colorFor(kind), size: 20),
        ),
      );
    }
    children.add(Expanded(child: text));
    for (final action in actions) {
      children.add(
        TextButton(
          onPressed: () {
            onActionPressed();
            action.onPressed();
          },
          child: Text(action.label),
        ),
      );
    }
    return Row(children: children);
  }

  static IconData _iconFor(AppFeedbackKind kind) {
    return switch (kind) {
      AppFeedbackKind.neutral => Icons.info_outline_rounded,
      AppFeedbackKind.success => Icons.check_circle_outline_rounded,
      AppFeedbackKind.warning => Icons.warning_amber_rounded,
      AppFeedbackKind.error => Icons.error_outline_rounded,
    };
  }

  static Color _colorFor(AppFeedbackKind kind) {
    return switch (kind) {
      AppFeedbackKind.neutral => AppColors.cyan,
      AppFeedbackKind.success => AppColors.success,
      AppFeedbackKind.warning => AppColors.warning,
      AppFeedbackKind.error => AppColors.error,
    };
  }
}
