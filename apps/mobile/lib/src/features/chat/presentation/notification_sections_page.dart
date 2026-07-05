import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../../profile/presentation/profile_page.dart';
import 'chat_room_page.dart';
import 'chat_widgets.dart';

typedef NotificationLoader = Future<List<ChatNotification>> Function(
  NotificationSection section,
);

typedef FollowerProfileOpener = void Function(ChatNotification notification);

class NotificationSectionsPage extends StatefulWidget {
  const NotificationSectionsPage({
    super.key,
    required this.initialSection,
    this.loadNotifications,
    this.openFollowerProfile,
  });

  final NotificationSection initialSection;
  final NotificationLoader? loadNotifications;
  final FollowerProfileOpener? openFollowerProfile;

  @override
  State<NotificationSectionsPage> createState() =>
      _NotificationSectionsPageState();
}

class _NotificationSectionsPageState extends State<NotificationSectionsPage> {
  late NotificationSection _section;
  ChatRepository? _repository;
  late Future<List<ChatNotification>> _future;

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
        return 'Activity Messages';
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

  @override
  Widget build(BuildContext context) {
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: Text(_title, style: chatAppBarTitleStyle),
        ),
        body: FutureBuilder<List<ChatNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ChatNoResultsState(
                title: 'No internet connection',
                subtitle: 'Please try again later',
                icon: Icons.wifi_off_rounded,
              );
            }

            final notifications = snapshot.data ?? const [];
            if (notifications.isEmpty) {
              return const ChatEmptyState(
                title: 'No notifications',
                subtitle:
                    'New updates will appear here when something happens.',
                icon: Icons.notifications_none_rounded,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isFollower = _section == NotificationSection.followers;
                final displayTitle = isFollower
                    ? (notification.actorName ?? 'New follower')
                    : notification.title;
                final displaySubtitle =
                    isFollower ? 'Started following you' : notification.body;
                return ListTile(
                  onTap: isFollower
                      ? () => _openFollowerProfile(notification)
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  leading: isFollower
                      ? ChatAvatar(
                          name: displayTitle,
                          avatarUrl: notification.actorAvatarUrl,
                        )
                      : CircleAvatar(
                          backgroundColor:
                              (notification.isUnread ? chatDanger : chatCyan)
                                  .withValues(alpha: 0.12),
                          child: Icon(
                            notification.isUnread
                                ? Icons.circle_notifications_rounded
                                : Icons.notifications_none_rounded,
                            color:
                                notification.isUnread ? chatDanger : chatCyan,
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
              },
            );
          },
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
