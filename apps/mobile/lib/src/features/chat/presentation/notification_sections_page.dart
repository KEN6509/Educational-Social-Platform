import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../posts/presentation/post_detail_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_room_page.dart';
import 'chat_widgets.dart';

typedef NotificationLoader = Future<List<ChatNotification>> Function(
  NotificationSection section,
);

typedef FollowerProfileOpener = void Function(ChatNotification notification);

typedef NotificationSectionReadMarker = Future<void> Function(
  NotificationSection section,
);

typedef ActivityPostOpener = Future<void> Function(
  ChatNotification notification,
);

class NotificationSectionsPage extends StatefulWidget {
  const NotificationSectionsPage({
    super.key,
    required this.initialSection,
    this.loadNotifications,
    this.openFollowerProfile,
    this.markSectionRead,
    this.openActivityPost,
  });

  final NotificationSection initialSection;
  final NotificationLoader? loadNotifications;
  final FollowerProfileOpener? openFollowerProfile;
  final NotificationSectionReadMarker? markSectionRead;
  final ActivityPostOpener? openActivityPost;

  @override
  State<NotificationSectionsPage> createState() =>
      _NotificationSectionsPageState();
}

class _NotificationSectionsPageState extends State<NotificationSectionsPage> {
  late NotificationSection _section;
  ChatRepository? _repository;
  late Future<List<ChatNotification>> _future;
  NotificationActivityFilter _activityFilter = NotificationActivityFilter.all;
  bool _showActivityFilters = false;
  bool _markedRead = false;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _future = _load();
  }

  Future<List<ChatNotification>> _load() {
    return widget.loadNotifications?.call(_section) ??
        _repo.fetchNotifications(_section);
  }

  String get _title {
    switch (_section) {
      case NotificationSection.activity:
        return 'Activity';
      case NotificationSection.system:
        return 'System Notifications';
      case NotificationSection.followers:
        return 'New Followers';
      case NotificationSection.chat:
        return 'Chat Messages';
    }
  }

  void _openFollowerProfile(ChatNotification notification) {
    final injected = widget.openFollowerProfile;
    if (injected != null) {
      injected(notification);
      return;
    }
    final actorId = notification.actorId;
    if (actorId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: actorId,
          initialName: notification.actorName,
          initialAvatarUrl: notification.actorAvatarUrl,
        ),
      ),
    );
  }

  Future<void> _markCurrentSectionRead() async {
    if (_markedRead || _section == NotificationSection.chat) return;
    _markedRead = true;
    final marker = widget.markSectionRead;
    if (marker != null) {
      await marker(_section);
      return;
    }
    await _repo.markNotificationsReadForSection(_section);
  }

  Future<void> _openActivityPost(ChatNotification notification) async {
    try {
      final injected = widget.openActivityPost;
      if (injected != null) {
        await injected(notification);
        return;
      }
      final postId = notification.postId;
      if (postId == null) {
        throw const ChatNotificationPostUnavailableException();
      }
      final post = await _repo.fetchPostForNotification(postId);
      if (post.moderationStatus != 'approved') {
        throw const ChatNotificationPostUnavailableException();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
      );
    } on ChatNotificationPostUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This post can't be viewed. It may be deleted or not approved yet.",
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }

  ({String title, String subtitle, IconData icon}) get _emptyState {
    if (_section == NotificationSection.followers) {
      return (
        title: 'No recent followers',
        subtitle: 'Followers from the last 30 days will appear here.',
        icon: Icons.group_outlined,
      );
    }
    if (_section == NotificationSection.activity) {
      return (
        title: 'No activity',
        subtitle: _activityFilter == NotificationActivityFilter.all
            ? 'Likes, saves, comments, and mentions will appear here.'
            : 'No ${_activityFilter.label.toLowerCase()} yet.',
        icon: Icons.notifications_none_rounded,
      );
    }
    return (
      title: 'No notifications',
      subtitle: 'New updates will appear here when something happens.',
      icon: Icons.notifications_none_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        _markCurrentSectionRead();
      },
      child: ChatNoSplash(
        child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () async {
              await _markCurrentSectionRead();
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: _section == NotificationSection.activity
              ? _ActivityFilterChip(
                  label: _activityFilter.label,
                  isExpanded: _showActivityFilters,
                  onTap: () => setState(
                    () => _showActivityFilters = !_showActivityFilters,
                  ),
                )
              : Text(_title, style: chatAppBarTitleStyle),
        ),
        body: Stack(
          children: [
            FutureBuilder<List<ChatNotification>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ChatNoResultsState(
                    title: 'No internet connection',
                    subtitle: 'Please try again later',
                    icon: Icons.wifi_off_rounded,
                  );
                }

                var notifications = snapshot.data ?? const [];
                if (_section == NotificationSection.activity) {
                  notifications = ChatRepository.filterActivityNotifications(
                    notifications,
                    _activityFilter,
                  );
                }

                if (notifications.isEmpty) {
                  final emptyState = _emptyState;
                  return ChatEmptyState(
                    title: emptyState.title,
                    subtitle: emptyState.subtitle,
                    icon: emptyState.icon,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    if (_section == NotificationSection.activity) {
                      return _ActivityNotificationTile(
                        notification: notification,
                        onTap: () => _openActivityPost(notification),
                      );
                    }
                    return _FollowerOrGenericNotificationTile(
                      notification: notification,
                      section: _section,
                      onFollowerTap: () => _openFollowerProfile(notification),
                    );
                  },
                );
              },
            ),
            if (_section == NotificationSection.activity &&
                _showActivityFilters)
              _ActivityFilterDropdown(
                selected: _activityFilter,
                onDismiss: () => setState(() => _showActivityFilters = false),
                onSelect: (filter) {
                  setState(() {
                    _activityFilter = filter;
                    _showActivityFilters = false;
                  });
                },
              ),
          ],
        ),
        ),
      ),
    );
  }
}

class _FollowerOrGenericNotificationTile extends StatelessWidget {
  const _FollowerOrGenericNotificationTile({
    required this.notification,
    required this.section,
    required this.onFollowerTap,
  });

  final ChatNotification notification;
  final NotificationSection section;
  final VoidCallback onFollowerTap;

  @override
  Widget build(BuildContext context) {
    final isFollower = section == NotificationSection.followers;
    final displayTitle = isFollower
        ? (notification.actorName ?? 'New follower')
        : notification.title;
    final displaySubtitle =
        isFollower ? 'Started following you' : notification.body;

    return ListTile(
      onTap: isFollower ? onFollowerTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      leading: isFollower
          ? ChatAvatar(
              name: displayTitle,
              avatarUrl: notification.actorAvatarUrl,
            )
          : CircleAvatar(
              backgroundColor: (notification.isUnread ? chatDanger : chatCyan)
                  .withValues(alpha: 0.12),
              child: Icon(
                notification.isUnread
                    ? Icons.circle_notifications_rounded
                    : Icons.notifications_none_rounded,
                color: notification.isUnread ? chatDanger : chatCyan,
              ),
            ),
      title: Text(
        displayTitle,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        isFollower
            ? '$displaySubtitle · ${_formatNotificationTime(notification.createdAt)}'
            : displaySubtitle,
      ),
      trailing: isFollower && notification.actorId != null
          ? _FollowerActionButton(notification: notification)
          : null,
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
    required this.onTap,
  });

  final ChatNotification notification;
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
            _ActivityAvatar(notification: notification, name: actorName),
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
  const _ActivityAvatar({required this.notification, required this.name});

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
  const _FollowerActionButton({required this.notification});

  final ChatNotification notification;

  @override
  State<_FollowerActionButton> createState() => _FollowerActionButtonState();
}

class _FollowerActionButtonState extends State<_FollowerActionButton> {
  ChatRepository? _repository;
  late Future<bool> _future = _loadFollowingState();
  bool _isBusy = false;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  Future<bool> _loadFollowingState() async {
    try {
      return await _repo.isFollowing(widget.notification.actorId!);
    } catch (_) {
      return false;
    }
  }

  Future<void> _follow() async {
    setState(() => _isBusy = true);
    try {
      await _repo.followUser(widget.notification.actorId!);
      if (mounted) setState(() => _future = Future.value(true));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
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
      final conversationId = await _repo.createDirectConversation(actorId);
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
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
            backgroundColor: following ? Colors.white : chatCyan,
            side: BorderSide(color: following ? chatCyan : Colors.transparent),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(78, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(following ? 'Message' : 'Follow'),
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
