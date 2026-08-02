import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../posts/presentation/post_detail_page.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';
import 'system_notification_widgets.dart';

typedef RejectedPostOpener = Future<void> Function(String postId);
typedef AppealStateLoader = Future<PostAppealState> Function(String postId);
typedef SystemNotificationReasonLoader = Future<String?> Function(
  String notificationId,
);
typedef AppealSubmitter = Future<void> Function(
  String postId,
  String reason,
);
typedef SystemNotificationDeleteAction = Future<void> Function(
  String notificationId,
);

class SystemNotificationDetailPage extends StatefulWidget {
  const SystemNotificationDetailPage({
    super.key,
    required this.notification,
    this.openRejectedPost,
    this.loadAppealState,
    this.loadDecisionReason,
    this.submitAppeal,
    this.deleteNotification,
  });

  final ChatNotification notification;
  final RejectedPostOpener? openRejectedPost;
  final AppealStateLoader? loadAppealState;
  final SystemNotificationReasonLoader? loadDecisionReason;
  final AppealSubmitter? submitAppeal;
  final SystemNotificationDeleteAction? deleteNotification;

  @override
  State<SystemNotificationDetailPage> createState() =>
      _SystemNotificationDetailPageState();
}

class _SystemNotificationDetailPageState
    extends State<SystemNotificationDetailPage> {
  ChatRepository? _repository;
  PostAppealState _appealState = PostAppealState.none;
  String? _resolvedDecisionReason;
  bool _loadingAppeal = false;
  bool _postUnavailable = false;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    if (_needsDecisionReasonRecovery) {
      _loadDecisionReason();
    }
    if (widget.notification.isAppealableModerationNotification &&
        widget.notification.postId != null) {
      _loadAppealState();
    }
  }

  bool get _needsDecisionReasonRecovery =>
      (widget.notification.actionPayload['decision_message']
              ?.toString()
              .trim()
              .isEmpty ??
          true);

  Future<void> _loadDecisionReason() async {
    try {
      final loader = widget.loadDecisionReason;
      final reason = await (loader?.call(widget.notification.id) ??
          _repo.fetchSystemNotificationReason(widget.notification.id));
      if (mounted && reason != null && reason.trim().isNotEmpty) {
        setState(() => _resolvedDecisionReason = reason.trim());
      }
    } catch (_) {
      // Existing fallback copy remains available if a legacy reason cannot be
      // recovered; new notifications carry the reason in their payload.
    }
  }

  Future<void> _loadAppealState() async {
    setState(() => _loadingAppeal = true);
    try {
      final postId = widget.notification.postId!;
      final loader = widget.loadAppealState;
      final state =
          await (loader?.call(postId) ?? _repo.fetchPostAppealState(postId));
      if (mounted) setState(() => _appealState = state);
    } catch (_) {
      // The action remains available; server validation still prevents
      // duplicate or stale submissions.
    } finally {
      if (mounted) setState(() => _loadingAppeal = false);
    }
  }

  Future<void> _openPost() async {
    final postId = widget.notification.postId;
    if (postId == null) return;
    try {
      final opener = widget.openRejectedPost;
      if (opener != null) {
        await opener(postId);
        return;
      }
      final post = await _repo.fetchPostForNotification(postId);
      if (!{'rejected', 'removed', 'approved'}
          .contains(post.moderationStatus)) {
        throw const ChatNotificationPostUnavailableException();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _postUnavailable = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This rejected post is no longer available.',
          ),
        ),
      );
    }
  }

  Future<void> _submitAppeal(String reason) async {
    final postId = widget.notification.postId;
    if (postId == null ||
        _appealState != PostAppealState.none ||
        _postUnavailable) {
      return;
    }
    final submitter = widget.submitAppeal;
    await (submitter?.call(postId, reason) ??
        _repo.submitPostAppeal(postId: postId, reason: reason));
  }

  void _markAppealSubmitted() {
    if (mounted) setState(() => _appealState = PostAppealState.pending);
  }

  Future<void> _delete() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      iconColor: chatDanger,
      iconBackgroundColor: chatDanger.withValues(alpha: 0.1),
      title: 'Delete notification?',
      message:
          'This removes the notification only. Related posts and appeals are not deleted.',
      primaryLabel: 'Delete',
      primaryColor: chatDanger,
      primaryKey: const ValueKey('confirm-delete-system-detail'),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleter = widget.deleteNotification;
      await (deleter?.call(widget.notification.id) ??
          _repo.deleteNotification(widget.notification.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this notification. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final isAppealable = notification.isAppealableModerationNotification &&
        notification.postId != null;
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          actions: [
            IconButton(
              tooltip: 'Delete notification',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Text(
              notification.systemDisplayTitle,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 27,
                height: 1.18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDetailDate(notification.createdAt),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              notification.systemBrief,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (notification.postId != null &&
                notification.systemPostTitle != null &&
                notification.systemPostTitle!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InlinePostLink(
                enabled: !_postUnavailable,
                onTap: _openPost,
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Admin:',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _SystemDecisionCard(
              reason:
                  _resolvedDecisionReason ?? notification.systemDecisionMessage,
            ),
            if (isAppealable) ...[
              if (_postUnavailable) ...[
                const SizedBox(height: 14),
                const Text(
                  key: ValueKey('rejected-post-unavailable-message'),
                  'This rejected post is no longer available.',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (!_loadingAppeal && !_postUnavailable) ...[
                const SizedBox(height: 16),
                PostAppealForm(
                  onSubmit: _submitAppeal,
                  onSubmitted: _markAppealSubmitted,
                  appealState: _appealState,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemDecisionCard extends StatelessWidget {
  const _SystemDecisionCard({
    required this.reason,
  });

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('system-notification-decision-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        reason,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InlinePostLink extends StatelessWidget {
  const _InlinePostLink({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      enabled: enabled,
      button: true,
      child: InkWell(
        key: const ValueKey('rejected-post-inline-link'),
        onTap: enabled ? onTap : null,
        child: Text(
          'View post',
          style: TextStyle(
            color: enabled ? chatMentionAccent : const Color(0xFF94A3B8),
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor:
                enabled ? chatMentionAccent : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

String _formatDetailDate(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} · $hour:$minute $period';
}
