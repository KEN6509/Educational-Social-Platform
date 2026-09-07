import 'dart:async';

import 'package:flutter/material.dart';

import '../application/moderation_submission_coordinator.dart';
import '../domain/content_moderation.dart';
import '../domain/pending_moderation_retry.dart';

class PendingModerationRetryBanner extends StatefulWidget {
  const PendingModerationRetryBanner({
    required this.controller,
    super.key,
  });

  final ModerationSubmissionCoordinator controller;

  @override
  State<PendingModerationRetryBanner> createState() =>
      _PendingModerationRetryBannerState();
}

class _PendingModerationRetryBannerState
    extends State<PendingModerationRetryBanner> {
  List<PendingModerationTarget> _targets = const [];
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(PendingModerationRetryBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final targets = await widget.controller.loadPendingTargets();
    if (!mounted) return;
    setState(() => _targets = targets);
  }

  Future<void> _retryAll() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    var completed = 0;
    String? errorMessage;
    for (final target in List<PendingModerationTarget>.of(_targets)) {
      try {
        final result = await widget.controller.retry(target);
        if (result.state != ContentModerationState.failed &&
            result.state != ContentModerationState.processing) {
          completed += 1;
        }
      } on ContentModerationFailure catch (error) {
        errorMessage = error.message;
      }
    }
    await _refresh();
    if (!mounted) return;
    setState(() => _retrying = false);
    final messenger = ScaffoldMessenger.of(context);
    if (errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    } else if (completed > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            completed == 1
                ? 'Moderation updated for 1 item.'
                : 'Moderation updated for $completed items.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targets.isEmpty) return const SizedBox.shrink();
    final count = _targets.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        border: Border.all(color: const Color(0xFFF0C36A)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_send_outlined,
            size: 22,
            color: Color(0xFF8A5A00),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 item waiting for moderation'
                  : '$count items waiting for moderation',
              style: const TextStyle(
                color: Color(0xFF5F450F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _retrying ? null : _retryAll,
            child: Text(_retrying ? 'Retrying...' : 'Retry now'),
          ),
        ],
      ),
    );
  }
}
