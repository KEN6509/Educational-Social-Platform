import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_room_page.dart';
import 'chat_widgets.dart';
import 'create_group_chat_page.dart';
import 'notification_sections_page.dart';

typedef ConversationLoader = Future<List<ChatConversation>> Function();
typedef CountLoader = Future<Map<NotificationSection, int>> Function();

enum _MessageFilter { all, unread, groups, requests }

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.loadConversations,
    this.loadRequests,
    this.loadCounts,
    this.onBadgeCountChanged,
  });

  final ConversationLoader? loadConversations;
  final ConversationLoader? loadRequests;
  final CountLoader? loadCounts;
  final ValueChanged<int>? onBadgeCountChanged;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _conversationsCacheKey = 'chat.cached_conversations.v1';
  static const _requestsCacheKey = 'chat.cached_requests.v1';
  static const _countsCacheKey = 'chat.cached_counts.v1';
  static const _eligiblePeopleCacheKey = 'chat.cached_eligible_people.v1';

  static List<ChatConversation> _cachedConversations =
      const <ChatConversation>[];
  static List<ChatConversation> _cachedRequests = const <ChatConversation>[];
  static Map<NotificationSection, int> _cachedCounts =
      const <NotificationSection, int>{};
  static List<ChatParticipant> _cachedEligiblePeople =
      const <ChatParticipant>[];
  static bool _eligiblePeopleOffline = false;

  ChatRepository? _repository;
  RealtimeChannel? _channel;
  late Future<_ChatHomeState> _future;
  late Future<List<ChatParticipant>> _eligiblePeopleFuture;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';
  _MessageFilter _messageFilter = _MessageFilter.all;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    _future = _load();
    _eligiblePeopleFuture =
        _shouldUseInjectedData ? Future.value(const []) : _loadEligiblePeople();
    if (!_shouldUseInjectedData) {
      _channel = _repo.subscribeToChatChanges(
        channelName: 'chat-home',
        onChange: (_) => _refresh(),
      );
    }
  }

  bool get _shouldUseInjectedData =>
      widget.loadConversations != null ||
      widget.loadRequests != null ||
      widget.loadCounts != null;

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _repo.unsubscribe(channel);
    }
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<_ChatHomeState> _load() async {
    await _restoreCachedHome();
    var conversations = _cachedConversations;
    var requests = _cachedRequests;
    var counts = _cachedCounts;

    try {
      conversations = await (widget.loadConversations?.call() ??
          _repo.fetchConversations());
      _cachedConversations = conversations.take(10).toList();
      await _saveConversationCache(
        _conversationsCacheKey,
        _cachedConversations,
      );
    } catch (_) {}
    try {
      requests =
          await (widget.loadRequests?.call() ?? _repo.fetchMessageRequests());
      _cachedRequests = requests.take(10).toList();
      await _saveConversationCache(_requestsCacheKey, _cachedRequests);
    } catch (_) {}
    try {
      counts = await (widget.loadCounts?.call() ??
          _repo.fetchUnreadNotificationCounts());
      _cachedCounts = counts;
      await _saveCountsCache(counts);
    } catch (_) {}

    final homeState = _ChatHomeState(
      conversations: conversations,
      requests: requests,
      counts: counts,
    );
    widget.onBadgeCountChanged?.call(
      ChatRepository.bottomChatBadgeCount(
        notificationCounts: counts,
        conversations: conversations,
      ),
    );
    return homeState;
  }

  Future<void> _restoreCachedHome() async {
    if (_cachedConversations.isNotEmpty || _cachedRequests.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedConversations =
          _decodeConversationCache(prefs.getString(_conversationsCacheKey));
      _cachedRequests =
          _decodeConversationCache(prefs.getString(_requestsCacheKey));
      _cachedCounts = _decodeCountsCache(prefs.getString(_countsCacheKey));
      _cachedEligiblePeople =
          _decodePeopleCache(prefs.getString(_eligiblePeopleCacheKey));
    } catch (_) {}
  }

  Future<void> _saveConversationCache(
    String key,
    List<ChatConversation> conversations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(conversations.map(_conversationToJson).toList()),
      );
    } catch (_) {}
  }

  Future<void> _saveCountsCache(Map<NotificationSection, int> counts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _countsCacheKey,
        jsonEncode(counts.map((key, value) => MapEntry(key.name, value))),
      );
    } catch (_) {}
  }

  static List<ChatConversation> _decodeConversationCache(String? value) {
    if (value == null || value.isEmpty) return const <ChatConversation>[];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const <ChatConversation>[];
      return decoded
          .whereType<Map>()
          .map((item) =>
              ChatConversation.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const <ChatConversation>[];
    }
  }

  static Map<NotificationSection, int> _decodeCountsCache(String? value) {
    if (value == null || value.isEmpty) {
      return const <NotificationSection, int>{};
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return const <NotificationSection, int>{};
      return decoded.map((key, value) {
        final section = NotificationSection.values.firstWhere(
          (item) => item.name == key,
          orElse: () => NotificationSection.chat,
        );
        return MapEntry(section, value is int ? value : 0);
      });
    } catch (_) {
      return const <NotificationSection, int>{};
    }
  }

  static Map<String, dynamic> _conversationToJson(
    ChatConversation conversation,
  ) {
    return {
      'id': conversation.id,
      'type': conversation.type.name,
      'request_status': conversation.requestStatus.name,
      'unread_count': conversation.unreadCount,
      'title': conversation.title,
      'other_user_id': conversation.otherUserId,
      'other_user_name': conversation.otherUserName,
      'other_user_avatar_url': conversation.otherUserAvatarUrl,
      'last_message_body': conversation.lastMessageBody,
      'last_message_at': conversation.lastMessageAt?.toIso8601String(),
      'created_by': conversation.createdBy,
      'created_by_name': conversation.createdByName,
      'created_at': conversation.createdAt?.toIso8601String(),
    };
  }

  Future<void> _savePeopleCache(List<ChatParticipant> people) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _eligiblePeopleCacheKey,
        jsonEncode(people.map(_participantToJson).toList()),
      );
    } catch (_) {}
  }

  static List<ChatParticipant> _decodePeopleCache(String? value) {
    if (value == null || value.isEmpty) return const <ChatParticipant>[];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const <ChatParticipant>[];
      return decoded
          .whereType<Map>()
          .map((item) =>
              ChatParticipant.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const <ChatParticipant>[];
    }
  }

  static Map<String, dynamic> _participantToJson(ChatParticipant participant) {
    return {
      'id': participant.id,
      'name': participant.name,
      'email': participant.email,
      'avatar_url': participant.avatarUrl,
      'role': participant.role,
      'is_selected': participant.isSelected,
    };
  }

  void _refresh() {
    setState(() {
      _future = _load();
      _eligiblePeopleFuture = _shouldUseInjectedData
          ? Future.value(const [])
          : _loadEligiblePeople();
    });
  }

  Future<List<ChatParticipant>> _loadEligiblePeople() async {
    await _restoreCachedHome();
    try {
      final people = await _repo.fetchSuggestedGroupMembers();
      _cachedEligiblePeople = people;
      _eligiblePeopleOffline = false;
      await _savePeopleCache(people);
      return people;
    } catch (_) {
      _eligiblePeopleOffline = true;
      return _cachedEligiblePeople;
    }
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _handleSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _cancelSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }

  Future<_ChatSearchState> _loadSearchResults(
    String normalized,
    List<ChatConversation> conversations,
  ) async {
    final matchingConversations = conversations.where((conversation) {
      return conversation.displayTitle.toLowerCase().contains(normalized);
    }).toList();

    final people = await _eligiblePeopleFuture;
    final conversationUserIds = conversations
        .where(
            (conversation) => conversation.type == ChatConversationType.direct)
        .map((conversation) => conversation.otherUserId)
        .whereType<String>()
        .toSet();

    final matchingPeople = people.where((person) {
      if (conversationUserIds.contains(person.id)) return false;
      return person.name.toLowerCase().contains(normalized);
    }).toList();

    return _ChatSearchState(
      conversations: matchingConversations,
      people: matchingPeople,
      isOffline: _eligiblePeopleOffline && people.isEmpty,
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
          centerTitle: false,
          titleSpacing: 16,
          title: const Text(
            'Messages',
            style: TextStyle(
              color: Color(0xFF0B1F3E),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Create group chat',
              icon: const Icon(
                Icons.group_add_rounded,
                color: Color(0xFF0B1F3E),
                size: 28,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateGroupChatPage()),
                );
                if (mounted) _refresh();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<_ChatHomeState>(
          future: _future,
          builder: (context, snapshot) {
            final state = snapshot.data ?? const _ChatHomeState();
            final conversations = state.conversations;
            final now = DateTime.now();
            final recentRequests = state.requests.where((request) {
              final at = request.lastMessageAt ?? request.createdAt;
              if (at == null) return true;
              return at.isAfter(
                now.subtract(const Duration(days: 30)),
              );
            }).toList();
            final unreadFilterCount = conversations
                .where((conversation) => conversation.unreadCount > 0)
                .length;
            final groupUnreadCount = conversations
                .where(
                  (conversation) =>
                      conversation.isGroup && conversation.unreadCount > 0,
                )
                .length;
            final requestUnreadCount = recentRequests
                .where((request) => request.unreadCount > 0)
                .length;
            final searching =
                ChatRepository.normalizeSearchTerm(_query).isNotEmpty;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ChatSearchField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            hintText: 'Search name or group',
                            onChanged: _handleSearchChanged,
                          ),
                        ),
                        if (_searchFocusNode.hasFocus || searching) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _cancelSearch,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (searching)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _SearchResultsList(
                        future: _loadSearchResults(
                          ChatRepository.normalizeSearchTerm(_query),
                          state.conversations,
                        ),
                        onConversationTap: _openRoom,
                        onPersonTap: _openParticipant,
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NotificationShortcut(
                              label: 'Activity',
                              icon: Icons.favorite_rounded,
                              backgroundColor: const Color(0xFFFFE4E6),
                              iconColor: const Color(0xFFBE123C),
                              count:
                                  state.counts[NotificationSection.activity] ??
                                      0,
                              onTap: () => _openNotifications(
                                  NotificationSection.activity),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NotificationShortcut(
                              label: 'System',
                              icon: Icons.notifications_rounded,
                              backgroundColor: const Color(0xFFE8F7EF),
                              iconColor: const Color(0xFF15803D),
                              count:
                                  state.counts[NotificationSection.system] ?? 0,
                              onTap: () => _openNotifications(
                                  NotificationSection.system),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NotificationShortcut(
                              label: 'New Followers',
                              icon: Icons.people_alt_rounded,
                              backgroundColor: const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF1D4ED8),
                              count:
                                  state.counts[NotificationSection.followers] ??
                                      0,
                              onTap: () => _openNotifications(
                                  NotificationSection.followers),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _MessageFilterBar(
                        selected: _messageFilter,
                        unreadCount: unreadFilterCount,
                        groupUnreadCount: groupUnreadCount,
                        requestUnreadCount: requestUnreadCount,
                        onChanged: (value) =>
                            setState(() => _messageFilter = value),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final visibleConversations = switch (_messageFilter) {
                          _MessageFilter.all => conversations,
                          _MessageFilter.unread => conversations
                              .where(
                                (conversation) => conversation.unreadCount > 0,
                              )
                              .toList(),
                          _MessageFilter.groups => conversations
                              .where((conversation) => conversation.isGroup)
                              .toList(),
                          _MessageFilter.requests => recentRequests,
                        };

                        if (visibleConversations.isEmpty &&
                            _messageFilter == _MessageFilter.requests) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: ChatNoResultsState(
                              title: 'No recent message requests',
                              subtitle:
                                  "Requests older than 30 days aren't shown.",
                              icon: Icons.mark_chat_unread_outlined,
                            ),
                          );
                        }

                        if (visibleConversations.isEmpty &&
                            _messageFilter == _MessageFilter.unread) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ChatNoResultsState(
                              title: 'No chats in Unread',
                              subtitleWidget: GestureDetector(
                                onTap: () => setState(
                                  () => _messageFilter = _MessageFilter.all,
                                ),
                                child: const Text(
                                  'View all chats',
                                  style: TextStyle(
                                    color: Color(0xFF128C7E),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              icon: Icons.mark_chat_read_outlined,
                            ),
                          );
                        }

                        if (visibleConversations.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: _EmptyChatState(),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: visibleConversations
                                .map(
                                  (conversation) => ConversationTile(
                                    conversation: conversation,
                                    onTap: () => _openRoom(conversation),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openParticipant(ChatParticipant participant) async {
    try {
      final conversationId =
          await _repo.createDirectConversation(participant.id);
      if (!mounted) return;
      _cancelSearch();
      await _openRoom(
        ChatConversation.fromMap({
          'id': conversationId,
          'type': 'direct',
          'request_status': 'accepted',
          'unread_count': 0,
          'other_user_id': participant.id,
          'other_user_name': participant.name,
          'other_user_avatar_url': participant.avatarUrl,
        }),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }

  Future<void> _openNotifications(NotificationSection section) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSectionsPage(initialSection: section),
      ),
    );
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openRoom(ChatConversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ChatRoomPage(conversation: conversation)),
    );
    if (mounted) _refresh();
  }
}

class _MessageFilterBar extends StatelessWidget {
  const _MessageFilterBar({
    required this.selected,
    required this.unreadCount,
    required this.groupUnreadCount,
    required this.requestUnreadCount,
    required this.onChanged,
  });

  final _MessageFilter selected;
  final int unreadCount;
  final int groupUnreadCount;
  final int requestUnreadCount;
  final ValueChanged<_MessageFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MessageFilterChip(
            label: 'All',
            selected: selected == _MessageFilter.all,
            onTap: () => onChanged(_MessageFilter.all),
          ),
          const SizedBox(width: 8),
          _MessageFilterChip(
            label: 'Unread',
            count: unreadCount,
            countKey: const ValueKey('message-filter-count-unread'),
            selected: selected == _MessageFilter.unread,
            onTap: () => onChanged(_MessageFilter.unread),
          ),
          const SizedBox(width: 8),
          _MessageFilterChip(
            label: 'Groups',
            count: groupUnreadCount,
            countKey: const ValueKey('message-filter-count-groups'),
            selected: selected == _MessageFilter.groups,
            onTap: () => onChanged(_MessageFilter.groups),
          ),
          const SizedBox(width: 8),
          _MessageFilterChip(
            label: 'Requests',
            count: requestUnreadCount,
            countKey: const ValueKey('message-filter-count-requests'),
            selected: selected == _MessageFilter.requests,
            onTap: () => onChanged(_MessageFilter.requests),
          ),
        ],
      ),
    );
  }
}

class _MessageFilterChip extends StatelessWidget {
  const _MessageFilterChip({
    required this.label,
    this.count,
    this.countKey,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final Key? countKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F7ED) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF128C7E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF128C7E)
                    : const Color(0xFF64748B),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Text(
                count.toString(),
                key: countKey,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF128C7E)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatHomeState {
  const _ChatHomeState({
    this.conversations = const [],
    this.requests = const [],
    this.counts = const {},
  });

  final List<ChatConversation> conversations;
  final List<ChatConversation> requests;
  final Map<NotificationSection, int> counts;
}

class _ChatSearchState {
  const _ChatSearchState({
    required this.conversations,
    required this.people,
    this.isOffline = false,
  });

  final List<ChatConversation> conversations;
  final List<ChatParticipant> people;
  final bool isOffline;
}

class _NotificationShortcut extends StatelessWidget {
  const _NotificationShortcut({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 114,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                if (count > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: UnreadBadge(count: count),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: chatNavy,
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.future,
    required this.onConversationTap,
    required this.onPersonTap,
  });

  final Future<_ChatSearchState> future;
  final ValueChanged<ChatConversation> onConversationTap;
  final ValueChanged<ChatParticipant> onPersonTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ChatSearchState>(
      future: future,
      builder: (context, snapshot) {
        final state = snapshot.data ??
            const _ChatSearchState(conversations: [], people: []);
        if (state.conversations.isEmpty && state.people.isEmpty) {
          if (state.isOffline) {
            return const ChatNoResultsState(
              title: 'No internet connection',
              subtitle: 'Connect to the internet to search people.',
              icon: Icons.wifi_off_rounded,
            );
          }
          return const ChatNoResultsState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.conversations.isNotEmpty) ...[
              const _SearchSectionTitle('Chats'),
              ...state.conversations.map(
                (conversation) => ConversationTile(
                  conversation: conversation,
                  onTap: () => onConversationTap(conversation),
                ),
              ),
            ],
            if (state.people.isNotEmpty) ...[
              const _SearchSectionTitle('People'),
              ...state.people.map((participant) {
                return GestureDetector(
                  onTap: () => onPersonTap(participant),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ChatAvatar(
                          name: participant.name,
                          avatarUrl: participant.avatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            participant.name,
                            style: const TextStyle(
                              color: chatNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: chatNavy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: chatBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: chatCyan, size: 38),
          SizedBox(height: 10),
          Text(
            'No chats yet',
            style: TextStyle(color: chatNavy, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text('Search followers/following or create a group to begin.'),
        ],
      ),
    );
  }
}
