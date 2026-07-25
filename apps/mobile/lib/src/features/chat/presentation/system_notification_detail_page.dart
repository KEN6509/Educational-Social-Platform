import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../posts/presentation/post_detail_page.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';
import 'system_notification_widgets.dart';

typedef RejectedPostOpener = Future<void> Function(String postId);
typedef AppealStateLoader = Future<bool> Function(String postId);
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
    this.loadAppealSubmitted,
    this.submitAppeal,
    this.deleteNotification,
  });

  final ChatNotification notification;
  final RejectedPostOpener? openRejectedPost;
  final AppealStateLoader? loadAppealSubmitted;
  final AppealSubmitter? submitAppeal;
  final SystemNotificationDeleteAction? deleteNotification;

  @override
  State<SystemNotificationDetailPage> createState() =>
      _SystemNotificationDetailPageState();
}

class _SystemNotificationDetailPageState
    extends State<SystemNotificationDetailPage> {
  ChatRepository? _repository;
  bool _appealSubmitted = false;
  bool _loadingAppeal = false;
  bool _postUnavailable = false;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    if (widget.notification.isPostRejection &&
        widget.notification.postId != null) {
      _loadAppealState();
    }
  }

  Future<void> _loadAppealState() async {
    setState(() => _loadingAppeal = true);
    try {
      final postId = widget.notification.postId!;
      final loader = widget.loadAppealSubmitted;
      final submitted =
          await (loader?.call(postId) ?? _repo.hasPostAppeal(postId));
      if (mounted) setState(() => _appealSubmitted = submitted);
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
      if (post.moderationStatus != 'rejected') {
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

  Future<void> _showAppealForm() async {
    final postId = widget.notification.postId;
    if (postId == null || _appealSubmitted || _postUnavailable) return;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostAppealForm(
        onSubmit: (reason) {
          final submitter = widget.submitAppeal;
          return submitter?.call(postId, reason) ??
              _repo.submitPostAppeal(postId: postId, reason: reason);
        },
      ),
    );
    if (submitted == true && mounted) {
      setState(() => _appealSubmitted = true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text(
          'This removes the notification only. Related posts and appeals are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-system-detail'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
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
    const bodyStyle = TextStyle(
      color: Color(0xFF334155),
      fontSize: 16,
      height: 1.55,
      fontWeight: FontWeight.w500,
    );
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: Colors.white,
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
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          children: [
            Text(
              notification.title,
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
            const SizedBox(height: 24),
            _SystemNotificationBody(
              notification: notification,
              style: bodyStyle,
              postUnavailable: _postUnavailable,
              onOpenPost: _openPost,
            ),
            if (notification.isPostRejection &&
                notification.postId != null) ...[
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _appealSubmitted || _loadingAppeal || _postUnavailable
                          ? null
                          : _showAppealForm,
                  icon: Icon(
                    _appealSubmitted
                        ? Icons.check_circle_outline_rounded
                        : Icons.gavel_rounded,
                  ),
                  label: Text(
                    _appealSubmitted ? 'Appeal submitted' : 'Send appeal',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemNotificationBody extends StatelessWidget {
  const _SystemNotificationBody({
    required this.notification,
    required this.style,
    required this.postUnavailable,
    required this.onOpenPost,
  });

  final ChatNotification notification;
  final TextStyle style;
  final bool postUnavailable;
  final VoidCallback onOpenPost;

  @override
  Widget build(BuildContext context) {
    final postTitle = notification.systemPostTitle;
    if (!notification.isPostRejection ||
        notification.postId == null ||
        postTitle == null ||
        postTitle.isEmpty) {
      return Text(notification.body, style: style);
    }

    final titleStart = notification.body.indexOf(postTitle);
    if (titleStart < 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body, style: style),
          const SizedBox(height: 12),
          _InlinePostLink(
            postTitle: postTitle,
            enabled: !postUnavailable,
            onTap: onOpenPost,
          ),
        ],
      );
    }

    final titleEnd = titleStart + postTitle.length;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: notification.body.substring(0, titleStart)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlinePostLink(
              postTitle: postTitle,
              enabled: !postUnavailable,
              onTap: onOpenPost,
            ),
          ),
          TextSpan(text: notification.body.substring(titleEnd)),
        ],
      ),
    );
  }
}

class _InlinePostLink extends StatelessWidget {
  const _InlinePostLink({
    required this.postTitle,
    required this.enabled,
    required this.onTap,
  });

  final String postTitle;
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
          postTitle,
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
