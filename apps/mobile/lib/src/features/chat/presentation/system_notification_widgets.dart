import 'package:flutter/material.dart';

import '../data/chat_models.dart';
import 'chat_widgets.dart';

class SystemNotificationCard extends StatelessWidget {
  const SystemNotificationCard({
    super.key,
    required this.notification,
    required this.isUnread,
    required this.onOpen,
    required this.onDelete,
  });

  final ChatNotification notification;
  final bool isUnread;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('system-notification-card-${notification.id}'),
      color:
          isUnread ? chatMentionAccent.withValues(alpha: 0.055) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isUnread
                  ? chatMentionAccent.withValues(alpha: 0.24)
                  : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFF1F5F9),
                        child: Icon(
                          Icons.campaign_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isUnread)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            key: ValueKey(
                              'notification-unread-dot-${notification.id}',
                            ),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: chatDanger,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'System Notification',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: ValueKey(
                      'system-notification-menu-${notification.id}',
                    ),
                    tooltip: 'Notification options',
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF64748B),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                notification.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 19,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notification.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatSystemNotificationDate(notification.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'View more',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSystemNotificationDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

class PostAppealForm extends StatefulWidget {
  const PostAppealForm({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(String reason) onSubmit;

  @override
  State<PostAppealForm> createState() => _PostAppealFormState();
}

class _PostAppealFormState extends State<PostAppealForm> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  String get _reason => _controller.text.trim();
  bool get _isValid => _reason.length >= 20 && _reason.length <= 500;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit your appeal. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send an appeal',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explain why you believe this post is suitable for CyanZone.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('post-appeal-reason'),
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 7,
                maxLength: 500,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: 'Write 20–500 characters',
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isValid && !_submitting ? _submit : null,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit appeal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
