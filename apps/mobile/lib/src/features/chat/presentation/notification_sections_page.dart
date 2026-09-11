import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../posts/presentation/post_detail_page.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../application/chat_refresh_coordinator.dart';
import 'chat_room_page.dart';
import 'chat_widgets.dart';
import 'system_notification_widgets.dart';
import 'system_notification_detail_page.dart';

part 'notification_section_widgets.dart';

typedef NotificationLoader = Future<List<ChatNotification>> Function(
  NotificationSection section,
);

typedef FollowerProfileOpener = void Function(ChatNotification notification);

typedef NotificationSectionReadMarker = Future<void> Function(
  NotificationSection section,
);

typedef NotificationReadMarker = Future<void> Function(String notificationId);

typedef ActivityPostOpener = Future<void> Function(
  ChatNotification notification,
);

typedef SystemNotificationOpener = Future<void> Function(
  ChatNotification notification,
);

typedef NotificationDeleter = Future<void> Function(String notificationId);

class NotificationSectionsPage extends StatefulWidget {
  const NotificationSectionsPage({
    super.key,
    required this.initialSection,
    this.loadNotifications,
    this.openFollowerProfile,
    this.markSectionRead,
    this.markNotificationRead,
    this.openActivityPost,
    this.openSystemNotification,
    this.deleteNotification,
  });

  final NotificationSection initialSection;
  final NotificationLoader? loadNotifications;
  final FollowerProfileOpener? openFollowerProfile;
  final NotificationSectionReadMarker? markSectionRead;
  final NotificationReadMarker? markNotificationRead;
  final ActivityPostOpener? openActivityPost;
  final SystemNotificationOpener? openSystemNotification;
  final NotificationDeleter? deleteNotification;

  @override
  State<NotificationSectionsPage> createState() =>
      _NotificationSectionsPageState();
}

class _NotificationSectionsPageState extends State<NotificationSectionsPage>
    with WidgetsBindingObserver {
  late NotificationSection _section;
  ChatRepository? _repository;
  RealtimeChannel? _notificationChannel;
  late final ChatRefreshCoordinator _refreshCoordinator;
  late Future<List<ChatNotification>> _future;
  NotificationActivityFilter _activityFilter = NotificationActivityFilter.all;
  bool _showActivityFilters = false;
  bool _markedRead = false;
  bool _isClosing = false;
  bool _allowPop = false;
  int _refreshGeneration = 0;
  final Set<String> _locallyReadNotificationIds = <String>{};

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _section = widget.initialSection;
    _future = _load();
    _refreshCoordinator = ChatRefreshCoordinator(
      refresh: _performRefresh,
    );
    if (widget.loadNotifications == null) {
      _notificationChannel = _repo.subscribeToNotificationChanges(
        channelName: 'notification-section-${_section.name}',
        onChange: (_) => _refreshCoordinator.schedule(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshCoordinator.dispose();
    final channel = _notificationChannel;
    if (channel != null) {
      _repo.unsubscribe(channel);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshNotifications();
    }
  }

  Future<List<ChatNotification>> _load() {
    return widget.loadNotifications?.call(_section) ??
        _repo.fetchNotifications(_section);
  }

  Future<void> _performRefresh() async {
    if (!mounted) return;
    final next = _load();
    setState(() {
      _refreshGeneration += 1;
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder retains the existing visible error behavior.
    }
  }

  void _refreshNotifications() {
    unawaited(_refreshCoordinator.refreshNow());
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

  bool _isNotificationUnread(ChatNotification notification) {
    return notification.isUnread &&
        !_locallyReadNotificationIds.contains(notification.id);
  }

  Future<void> _markNotificationReadLocally(
    ChatNotification notification,
  ) async {
    if (!_isNotificationUnread(notification)) return;
    setState(() => _locallyReadNotificationIds.add(notification.id));
    try {
      final marker = widget.markNotificationRead;
      if (marker != null) {
        await marker(notification.id);
      } else {
        await _repo.markNotificationRead(notification.id);
      }
    } catch (_) {}
  }

  Future<void> _openFollowerProfile(ChatNotification notification) async {
    _markNotificationReadLocally(notification);
    final injected = widget.openFollowerProfile;
    if (injected != null) {
      injected(notification);
      _refreshNotifications();
      return;
    }
    final actorId = notification.actorId;
    if (actorId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: actorId,
          initialName: notification.actorName,
          initialAvatarUrl: notification.actorAvatarUrl,
        ),
      ),
    );
    _refreshNotifications();
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

  Future<void> _close() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    try {
      await _markCurrentSectionRead();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(true);
  }

  Future<void> _openActivityPost(ChatNotification notification) async {
    try {
      final injected = widget.openActivityPost;
      if (injected != null) {
        await injected(notification);
        _refreshNotifications();
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
        MaterialPageRoute(
          builder: (_) => PostDetailPage(
            post: post,
            initialCommentId: notification.commentId,
          ),
        ),
      );
      _refreshNotifications();
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

  Future<void> _openSystemNotification(
    ChatNotification notification,
  ) async {
    await _markNotificationReadLocally(notification);
    if (!mounted) return;
    final opener = widget.openSystemNotification;
    if (opener != null) {
      await opener(notification);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SystemNotificationDetailPage(
            notification: notification,
          ),
        ),
      );
    }
    if (!mounted) return;
    _refreshNotifications();
  }

  Future<void> _deleteSystemNotification(
    ChatNotification notification,
  ) async {
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
      primaryKey: const ValueKey('confirm-delete-system-notification'),
    );
    if (confirmed != true || !mounted) return;

    try {
      final deleter = widget.deleteNotification;
      if (deleter != null) {
        await deleter(notification.id);
      } else {
        await _repo.deleteNotification(notification.id);
      }
      _refreshNotifications();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this notification. Please retry.'),
        ),
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
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, __) {
        if (didPop) return;
        _close();
      },
      child: ChatNoSplash(
        child: Scaffold(
          backgroundColor: _section == NotificationSection.system
              ? const Color(0xFFF4F6F8)
              : Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: IconButton(
              onPressed: _close,
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
                    separatorBuilder: (_, __) =>
                        _section == NotificationSection.system
                            ? const SizedBox(height: 12)
                            : const Divider(
                                height: 1,
                                indent: 62,
                                color: Color(0xFFE2E8F0),
                              ),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      if (_section == NotificationSection.system) {
                        return SystemNotificationCard(
                          notification: notification,
                          isUnread: _isNotificationUnread(notification),
                          onOpen: () => _openSystemNotification(notification),
                          onDelete: () =>
                              _deleteSystemNotification(notification),
                        );
                      }
                      if (_section == NotificationSection.activity) {
                        return _ActivityNotificationTile(
                          notification: notification,
                          isUnread: _isNotificationUnread(notification),
                          onTap: () {
                            _markNotificationReadLocally(notification);
                            _openActivityPost(notification);
                          },
                        );
                      }
                      return _FollowerOrGenericNotificationTile(
                        notification: notification,
                        section: _section,
                        isUnread: _isNotificationUnread(notification),
                        refreshGeneration: _refreshGeneration,
                        onNotificationRead: () =>
                            _markNotificationReadLocally(notification),
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
