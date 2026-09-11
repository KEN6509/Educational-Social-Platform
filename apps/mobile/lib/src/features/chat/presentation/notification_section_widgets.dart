part of 'notification_sections_page.dart';

class _FollowerOrGenericNotificationTile extends StatelessWidget {
  const _FollowerOrGenericNotificationTile({
    required this.notification,
    required this.section,
    required this.isUnread,
    required this.refreshGeneration,
    required this.onNotificationRead,
    required this.onFollowerTap,
  });

  final ChatNotification notification;
  final NotificationSection section;
  final bool isUnread;
  final int refreshGeneration;
  final Future<void> Function() onNotificationRead;
  final VoidCallback onFollowerTap;

  @override
  Widget build(BuildContext context) {
    final isFollower = section == NotificationSection.followers;
    final displayTitle = isFollower
        ? (notification.actorName ?? 'New follower')
        : notification.title;
    final displaySubtitle =
        isFollower ? 'Started following you' : notification.body;

    return InkWell(
      onTap: isFollower ? onFollowerTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        child: Row(
          children: [
            _NotificationLeadingAvatar(
              isUnread: isUnread,
              notificationId: notification.id,
              child: isFollower
                  ? ChatAvatar(
                      name: displayTitle,
                      avatarUrl: notification.actorAvatarUrl,
                    )
                  : CircleAvatar(
                      backgroundColor: (isUnread ? chatDanger : chatCyan)
                          .withValues(alpha: 0.12),
                      child: Icon(
                        isUnread
                            ? Icons.circle_notifications_rounded
                            : Icons.notifications_none_rounded,
                        color: isUnread ? chatDanger : chatCyan,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NotificationRowText(
                title: displayTitle,
                subtitle: displaySubtitle,
                createdAt: notification.createdAt,
              ),
            ),
            if (isFollower && notification.actorId != null) ...[
              const SizedBox(width: 10),
              _FollowerActionButton(
                key: ValueKey(
                  'follower-action-${notification.id}-$refreshGeneration',
                ),
                notification: notification,
                onNotificationRead: onNotificationRead,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationRowText extends StatelessWidget {
  const _NotificationRowText({
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  final String title;
  final String subtitle;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 14,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatNotificationTime(createdAt),
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NotificationUnreadDot extends StatelessWidget {
  const _NotificationUnreadDot({required this.notificationId});

  final String notificationId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('notification-unread-dot-$notificationId'),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: chatDanger,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _NotificationLeadingAvatar extends StatelessWidget {
  const _NotificationLeadingAvatar({
    required this.child,
    required this.isUnread,
    required this.notificationId,
  });

  final Widget child;
  final bool isUnread;
  final String notificationId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        if (isUnread)
          Positioned(
            left: -8,
            child: _NotificationUnreadDot(notificationId: notificationId),
          ),
      ],
    );
  }
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({
    required this.label,
    required this.isExpanded,
    required this.onTap,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: chatAppBarTitleStyle),
          const SizedBox(width: 4),
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF111827),
          ),
        ],
      ),
    );
  }
}

class _ActivityFilterDropdown extends StatelessWidget {
  const _ActivityFilterDropdown({
    required this.selected,
    required this.onSelect,
    required this.onDismiss,
  });

  final NotificationActivityFilter selected;
  final ValueChanged<NotificationActivityFilter> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.12),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: NotificationActivityFilter.values.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 20,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final filter = NotificationActivityFilter.values[index];
                  return ListTile(
                    onTap: () => onSelect(filter),
                    title: Text(
                      filter.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    trailing: filter == selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF0B1F3E),
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityNotificationTile extends StatelessWidget {
  const _ActivityNotificationTile({
    required this.notification,
    required this.isUnread,
    required this.onTap,
  });

  final ChatNotification notification;
  final bool isUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actorName = notification.actorName ?? 'Someone';
    return InkWell(
      onTap: notification.postId == null ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            _NotificationLeadingAvatar(
              isUnread: isUnread,
              notificationId: notification.id,
              child: _ActivityAvatar(
                notification: notification,
                name: actorName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.activityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatNotificationTime(notification.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ActivityPostPreview(notification: notification),
          ],
        ),
      ),
    );
  }
}

class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({
    required this.notification,
    required this.name,
  });

  final ChatNotification notification;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChatAvatar(name: name, avatarUrl: notification.actorAvatarUrl),
        Positioned(
          right: -2,
          bottom: -2,
          child: _ActivityBadge(notification: notification),
        ),
      ],
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.notification});

  final ChatNotification notification;

  @override
  Widget build(BuildContext context) {
    final data = switch (notification.type) {
      'like' => (
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE5484D),
        ),
      'favorite' => (
          icon: Icons.bookmark_rounded,
          color: const Color(0xFFEAB308),
        ),
      'mention' => (
          icon: Icons.alternate_email_rounded,
          color: const Color(0xFF16A34A),
        ),
      'comment_like' => (
          icon: Icons.favorite_rounded,
          color: const Color(0xFF2563EB),
        ),
      _ => (
          icon: Icons.mode_comment_rounded,
          color: const Color(0xFF2563EB),
        ),
    };

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: data.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(data.icon, size: 11, color: Colors.white),
    );
  }
}

class _ActivityPostPreview extends StatelessWidget {
  const _ActivityPostPreview({required this.notification});

  final ChatNotification notification;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        notification.postFirstImageUrl ?? notification.postAuthorAvatarUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFF1F5F9),
        child: imageUrl == null
            ? const Icon(
                Icons.article_outlined,
                color: Color(0xFF94A3B8),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.article_outlined,
                  color: Color(0xFF94A3B8),
                ),
              ),
      ),
    );
  }
}

class _FollowerActionButton extends StatefulWidget {
  const _FollowerActionButton({
    super.key,
    required this.notification,
    required this.onNotificationRead,
  });

  final ChatNotification notification;
  final Future<void> Function() onNotificationRead;

  @override
  State<_FollowerActionButton> createState() => _FollowerActionButtonState();
}

class _FollowerActionButtonState extends State<_FollowerActionButton> {
  ChatRepository? _repository;
  ProfileRepository? _profileRepository;
  late Future<bool> _future = _loadFollowingState();
  bool _isBusy = false;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  ProfileRepository get _profileRepo =>
      _profileRepository ??= ProfileRepository(Supabase.instance.client);

  Future<bool> _loadFollowingState() async {
    try {
      return await _profileRepo.isFollowing(widget.notification.actorId!);
    } catch (_) {
      return false;
    }
  }

  Future<void> _follow() async {
    setState(() => _isBusy = true);
    try {
      final actorId = widget.notification.actorId!;
      await _profileRepo.followUser(actorId);
      try {
        await widget.onNotificationRead();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _future = Future.value(true);
        });
      }
    } catch (error) {
      debugPrint('Follow back failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not follow back. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _message() async {
    setState(() => _isBusy = true);
    try {
      final actorId = widget.notification.actorId!;
      try {
        await widget.onNotificationRead();
      } catch (_) {}
      final conversationId = await _repo.openDirectConversation(actorId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            conversation: ChatConversation.fromMap({
              'id': conversationId,
              'type': 'direct',
              'request_status': 'accepted',
              'unread_count': 0,
              'other_user_id': actorId,
              'other_user_name':
                  widget.notification.actorName ?? 'New follower',
              'other_user_avatar_url': widget.notification.actorAvatarUrl,
            }),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        final text = error.toString().contains('Follow relationship required')
            ? 'Follow this user before sending a message.'
            : 'No internet connection';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        return OutlinedButton(
          onPressed: _isBusy ? null : (following ? _message : _follow),
          style: OutlinedButton.styleFrom(
            foregroundColor: following ? chatCyan : Colors.white,
            backgroundColor: following ? const Color(0xFFF1F5F9) : chatCyan,
            side: const BorderSide(color: Colors.transparent),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(78, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(following ? 'Message' : 'Follow back'),
        );
      },
    );
  }
}

String _formatNotificationTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${value.month}/${value.day}';
}
