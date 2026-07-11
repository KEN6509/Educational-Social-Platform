import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../posts/data/feed_post.dart';
import '../../posts/data/posts_repository.dart';
import 'chat_models.dart';
import 'chat_mention.dart';

enum NotificationActivityFilter {
  all('Activity'),
  likesFavorites('Likes & Favorites'),
  comments('Comments'),
  mentions('Mentions');

  const NotificationActivityFilter(this.label);

  final String label;
}

class ChatNotificationPostUnavailableException implements Exception {
  const ChatNotificationPostUnavailableException();

  @override
  String toString() => 'ChatNotificationPostUnavailableException';
}

class ChatImageUpload {
  const ChatImageUpload({
    required this.fileName,
    required this.bytes,
    required this.contentType,
    this.aspectRatio,
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;
  final double? aspectRatio;
}

class ChatRepository {
  ChatRepository(this._client);

  static const createDirectConversationRpc = 'create_direct_conversation';
  static const createGroupConversationRpc = 'create_group_conversation';
  static const sendChatMessageRpc = 'send_chat_message';
  static const acceptMessageRequestRpc = 'accept_message_request';
  static const clearChatRpc = 'clear_chat';
  static const renameGroupConversationRpc = 'rename_group_conversation';
  static const addGroupMembersRpc = 'add_group_members';
  static const exitGroupConversationRpc = 'exit_group_conversation';
  static const removeGroupMemberRpc = 'remove_group_member';
  static const deleteChatMessageForMeRpc = 'delete_chat_message_for_me';
  static const restoreChatMessageForMeRpc = 'restore_chat_message_for_me';
  static const unsendChatMessageRpc = 'unsend_chat_message';
  static const markConversationReadRpc = 'mark_conversation_read';
  static const markNotificationReadRpc = 'mark_notification_read';
  static const markNotificationSectionReadRpc =
      'mark_notification_section_read';
  static const fetchUnvisitedChatMentionsRpc = 'fetch_unvisited_chat_mentions';
  static const markChatMentionVisitedRpc = 'mark_chat_mention_visited';

  static const sendConversationIdParam = 'p_conversation_id';
  static const sendBodyParam = 'p_body';
  static const sendMentionsParam = 'p_mentions';
  static const conversationIdParam = 'p_conversation_id';
  static const messageIdParam = 'p_message_id';
  static const memberIdParam = 'p_member_id';
  static const notificationIdParam = 'p_notification_id';

  static const _conversationSelectColumns = '''
    id,
    type,
    title,
    created_by,
    requested_by,
    requested_to,
    request_status,
    created_at,
    updated_at,
    last_message_at
  ''';

  static const _messageSelectColumns =
      'id, conversation_id, sender_id, body, created_at, deleted_at, deleted_for, '
      'profiles!chat_messages_sender_id_fkey(name, avatar_url), '
      'chat_message_mentions(mentioned_user_id, display_text, start_offset, '
      'end_offset, is_all_source, visited_at)';

  static const _notificationSelectColumns =
      'id, type, actor_id, post_id, comment_id, title, body, created_at, read_at, '
      'profiles!notifications_actor_id_fkey(name, avatar_url), '
      'posts!notifications_post_id_fkey(author_id, '
      'profiles!posts_author_id_fkey(avatar_url), '
      'post_images(public_url, position))';

  static const _profileSelectColumns = 'id, name, email, avatar_url';

  final SupabaseClient _client;

  static String normalizeSearchTerm(String term) {
    return term.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
  }

  static List<ChatNotification> visibleNewFollowerNotifications(
    List<ChatNotification> notifications, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final cutoff = reference.subtract(const Duration(days: 30));
    final byActor = <String, ChatNotification>{};

    for (final notification in notifications) {
      if (notification.section != NotificationSection.followers ||
          notification.createdAt.isBefore(cutoff) ||
          notification.actorId == null) {
        continue;
      }
      final key = notification.actorId!;
      final existing = byActor[key];
      if (existing == null ||
          notification.createdAt.isAfter(existing.createdAt)) {
        byActor[key] = notification;
      }
    }

    final result = byActor.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static List<ChatNotification> filterActivityNotifications(
    List<ChatNotification> notifications,
    NotificationActivityFilter filter,
  ) {
    if (filter == NotificationActivityFilter.all) {
      return notifications
          .where((item) => item.section == NotificationSection.activity)
          .toList();
    }

    final expectedGroup = switch (filter) {
      NotificationActivityFilter.likesFavorites =>
        NotificationActivityGroup.likesFavorites,
      NotificationActivityFilter.comments => NotificationActivityGroup.comments,
      NotificationActivityFilter.mentions => NotificationActivityGroup.mentions,
      NotificationActivityFilter.all => NotificationActivityGroup.other,
    };

    return notifications
        .where(
          (item) =>
              item.section == NotificationSection.activity &&
              item.activityGroup == expectedGroup,
        )
        .toList();
  }

  static int bottomChatBadgeCount({
    required Map<NotificationSection, int> notificationCounts,
    required List<ChatConversation> conversations,
  }) {
    final notificationSources = [
      NotificationSection.activity,
      NotificationSection.system,
      NotificationSection.followers,
    ].where((section) => (notificationCounts[section] ?? 0) > 0).length;
    final unreadConversations = conversations
        .where((conversation) => conversation.unreadCount > 0)
        .length;
    return notificationSources + unreadConversations;
  }

  static Map<NotificationSection, int> countUnreadNotificationSections(
    List<ChatNotification> notifications, {
    DateTime? now,
  }) {
    final counts = {
      for (final section in NotificationSection.values) section: 0,
    };
    final reference = now ?? DateTime.now();
    final followers = visibleNewFollowerNotifications(
      notifications
          .where((notification) =>
              notification.section == NotificationSection.followers)
          .toList(),
      now: reference,
    );

    counts[NotificationSection.followers] = followers.length;

    for (final notification in notifications) {
      if (notification.section == NotificationSection.followers) {
        continue;
      }
      counts[notification.section] = (counts[notification.section] ?? 0) + 1;
    }

    return counts;
  }

  static int calculateUnreadConversationCount({
    required List<Map<String, dynamic>> messages,
    required String currentUserId,
    DateTime? lastReadAt,
    DateTime? clearedAt,
  }) {
    return messages.where((message) {
      final senderId = _string(message['sender_id'] ?? message['senderId']);
      if (senderId.isEmpty || senderId == currentUserId) return false;
      if (message['deleted_at'] != null || message['deletedAt'] != null) {
        return false;
      }
      final createdAt = _dateTimeFromObject(
        message['created_at'] ?? message['createdAt'],
      );
      if (createdAt == null) return false;
      if (lastReadAt != null && !createdAt.isAfter(lastReadAt)) return false;
      if (clearedAt != null && !createdAt.isAfter(clearedAt)) return false;
      return true;
    }).length;
  }

  Future<String> createDirectConversation(String targetUserId) async {
    final response = await _client.rpc<String>(
      createDirectConversationRpc,
      params: {'target_user_id': targetUserId},
    );
    return _stringIdFromRpc(response);
  }

  Future<String> createGroupConversation({
    String? title,
    required List<String> memberIds,
  }) async {
    final response = await _client.rpc<String>(
      createGroupConversationRpc,
      params: {
        'title': title,
        'member_ids': memberIds,
      },
    );
    return _stringIdFromRpc(response);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
    List<ChatMention> mentions = const [],
  }) async {
    await _client.rpc<Object?>(
      sendChatMessageRpc,
      params: {
        sendConversationIdParam: conversationId,
        sendBodyParam: body,
        sendMentionsParam: mentions
            .where((mention) => mention.matches(body))
            .map((mention) => mention.toRpcMap(body))
            .toList(),
      },
    );
  }

  Future<List<UnvisitedChatMention>> fetchUnvisitedMentions({
    String? conversationId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      fetchUnvisitedChatMentionsRpc,
      params: {'p_conversation_id': conversationId},
    );
    return response
        .whereType<Map>()
        .map((row) => UnvisitedChatMention.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<UnvisitedChatMention>> _tryFetchUnvisitedMentions() async {
    try {
      return await fetchUnvisitedMentions();
    } catch (_) {
      return const [];
    }
  }

  Future<void> markMentionVisited(String messageId) async {
    await _client.rpc<void>(
      markChatMentionVisitedRpc,
      params: {messageIdParam: messageId},
    );
  }

  Future<void> sendImageMessage({
    required String conversationId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    double? aspectRatio,
  }) async {
    final currentUserId = _requireCurrentUserId();
    final extension = _extensionFor(fileName, contentType);
    final storagePath =
        'chat/$currentUserId/$conversationId/${DateTime.now().microsecondsSinceEpoch}$extension';

    await _client.storage.from('images').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final publicUrl = _client.storage.from('images').getPublicUrl(
          storagePath,
        );
    await sendMessage(
      conversationId: conversationId,
      body: '${ChatMessage.imagePrefix}${jsonEncode({
            'url': publicUrl,
            'path': storagePath,
            if (aspectRatio != null) 'aspectRatio': aspectRatio,
          })}',
    );
  }

  Future<void> sendImageMessages({
    required String conversationId,
    required List<ChatImageUpload> images,
  }) async {
    if (images.isEmpty) return;
    if (images.length == 1) {
      final image = images.first;
      return sendImageMessage(
        conversationId: conversationId,
        fileName: image.fileName,
        bytes: image.bytes,
        contentType: image.contentType,
        aspectRatio: image.aspectRatio,
      );
    }

    final payloads = <Map<String, Object>>[];
    for (final image in images) {
      final currentUserId = _requireCurrentUserId();
      final extension = _extensionFor(image.fileName, image.contentType);
      final storagePath =
          'chat/$currentUserId/$conversationId/${DateTime.now().microsecondsSinceEpoch}-${payloads.length}$extension';

      await _client.storage.from('images').uploadBinary(
            storagePath,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: false,
            ),
          );
      payloads.add({
        'url': _client.storage.from('images').getPublicUrl(storagePath),
        'path': storagePath,
        if (image.aspectRatio != null) 'aspectRatio': image.aspectRatio!,
      });
    }

    await sendMessage(
      conversationId: conversationId,
      body: '${ChatMessage.multiImagePrefix}${jsonEncode(payloads)}',
    );
  }

  Future<void> acceptMessageRequest(String conversationId) async {
    await _client.rpc<void>(
      acceptMessageRequestRpc,
      params: {conversationIdParam: conversationId},
    );
  }

  Future<void> clearChat(String conversationId) async {
    await _client.rpc<void>(
      clearChatRpc,
      params: {conversationIdParam: conversationId},
    );
  }

  Future<void> renameGroupConversation({
    required String conversationId,
    required String? title,
  }) async {
    await _client.rpc<void>(
      renameGroupConversationRpc,
      params: {
        conversationIdParam: conversationId,
        'p_title': title,
      },
    );
  }

  Future<void> addGroupMembers({
    required String conversationId,
    required List<String> memberIds,
  }) async {
    await _client.rpc<void>(
      addGroupMembersRpc,
      params: {
        conversationIdParam: conversationId,
        'p_member_ids': memberIds,
      },
    );
  }

  Future<void> exitGroupConversation(String conversationId) async {
    final participants = await fetchConversationParticipants(conversationId);
    final isLastActiveMember = participants.length <= 1;
    final storagePaths = isLastActiveMember
        ? (await fetchMessages(conversationId))
            .expand((message) => message.imageStoragePaths)
            .toSet()
            .toList()
        : const <String>[];

    await _client.rpc<void>(
      exitGroupConversationRpc,
      params: {conversationIdParam: conversationId},
    );

    if (storagePaths.isNotEmpty) {
      await deleteImageStoragePaths(storagePaths);
    }
  }

  Future<void> removeGroupMember({
    required String conversationId,
    required String memberId,
  }) async {
    await _client.rpc<void>(
      removeGroupMemberRpc,
      params: {
        conversationIdParam: conversationId,
        memberIdParam: memberId,
      },
    );
  }

  Future<void> deleteMessageForMe(String messageId) async {
    await _client.rpc<void>(
      deleteChatMessageForMeRpc,
      params: {messageIdParam: messageId},
    );
  }

  Future<void> restoreMessageForMe(String messageId) async {
    await _client.rpc<void>(
      restoreChatMessageForMeRpc,
      params: {messageIdParam: messageId},
    );
  }

  Future<void> unsendMessage(String messageId) async {
    await _client.rpc<void>(
      unsendChatMessageRpc,
      params: {messageIdParam: messageId},
    );
  }

  Future<void> deleteImageStoragePaths(List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from('images').remove(paths);
  }

  Future<List<ChatParticipant>> fetchConversationParticipants(
    String conversationId,
  ) async {
    final memberRows = await _client
        .from('chat_conversation_members')
        .select('user_id,status,role')
        .eq('conversation_id', conversationId)
        .eq('status', ChatMemberStatus.active.name)
        .limit(200);
    final members = _mapListFromResponse(memberRows);
    final ids = members
        .map((row) => _string(row['user_id']))
        .where((id) => id.isNotEmpty)
        .toList();
    final profilesById = await _fetchProfilesById(ids);
    return members.map((member) {
      final userId = _string(member['user_id']);
      final profile = profilesById[userId] ?? <String, dynamic>{'id': userId};
      return ChatParticipant.fromMap({
        ...profile,
        'role': member['role'],
      });
    }).toList();
  }

  Future<void> markConversationRead(String conversationId) async {
    await _client.rpc<void>(
      markConversationReadRpc,
      params: {conversationIdParam: conversationId},
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client.rpc<void>(
      markNotificationReadRpc,
      params: {notificationIdParam: notificationId},
    );
  }

  Future<List<ChatConversation>> fetchConversations() async {
    final response = await _client
        .from('chat_conversations')
        .select(_conversationSelectColumns)
        .neq('request_status', ChatRequestStatus.pending.name)
        .order('last_message_at', ascending: false);

    return _hydrateConversations(_mapListFromResponse(response));
  }

  Future<List<ChatConversation>> fetchMessageRequests() async {
    final response = await _client
        .from('chat_conversations')
        .select(_conversationSelectColumns)
        .eq('request_status', ChatRequestStatus.pending.name)
        .order('last_message_at', ascending: false);

    return _hydrateConversations(_mapListFromResponse(response));
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final currentUserId = _requireCurrentUserId();
    final response = await _client
        .from('chat_messages')
        .select(_messageSelectColumns)
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(50);

    return _mapListFromResponse(response)
        .map((row) => ChatMessage.fromMap(row, currentUserId: currentUserId))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<ChatMessage>> fetchMessagesByIds(List<String> messageIds) async {
    if (messageIds.isEmpty) return const [];
    final currentUserId = _requireCurrentUserId();
    final response = await _client
        .from('chat_messages')
        .select(_messageSelectColumns)
        .inFilter('id', messageIds.toSet().toList());
    return _mapListFromResponse(response)
        .map((row) => ChatMessage.fromMap(row, currentUserId: currentUserId))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<ChatNotification>> fetchNotifications(
    NotificationSection section,
  ) async {
    var query =
        _client.from('notifications').select(_notificationSelectColumns);
    int? limit;

    switch (section) {
      case NotificationSection.activity:
        query = query.not(
          'type',
          'in',
          '(system,new_follower,chat_message)',
        );
      case NotificationSection.system:
        query = query.eq('type', 'system');
      case NotificationSection.followers:
        query = query.eq('type', 'new_follower');
        limit = 100;
      case NotificationSection.chat:
        query = query.eq('type', 'chat_message');
    }

    final ordered = query.order('created_at', ascending: false);
    final response = await (limit == null ? ordered : ordered.limit(limit));
    final notifications = _notificationListFromResponse(response);
    if (section == NotificationSection.followers) {
      return visibleNewFollowerNotifications(notifications);
    }
    return notifications;
  }

  Future<void> markNotificationsReadForSection(
    NotificationSection section,
  ) async {
    if (section == NotificationSection.chat) return;
    await _client.rpc<void>(
      markNotificationSectionReadRpc,
      params: {'p_section': section.name},
    );
  }

  Future<FeedPost> fetchPostForNotification(String postId) {
    return PostsRepository(_client).fetchPostById(postId);
  }

  Future<int> fetchUnreadChatCount() async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('type', 'chat_message')
        .isFilter('read_at', null);

    return _mapListFromResponse(response).length;
  }

  Future<int> fetchUnreadChatTabBadgeCount() async {
    final conversations = await fetchConversations();
    final counts = await fetchUnreadNotificationCounts();
    return bottomChatBadgeCount(
      notificationCounts: counts,
      conversations: conversations,
    );
  }

  Future<Map<NotificationSection, int>> fetchUnreadNotificationCounts() async {
    final response = await _client
        .from('notifications')
        .select(_notificationSelectColumns)
        .isFilter('read_at', null);

    return countUnreadNotificationSections(
        _notificationListFromResponse(response));
  }

  Future<List<ChatParticipant>> searchPeopleAndChats(String term) async {
    final searchTerm = _safeSearchTerm(term);
    if (searchTerm.isEmpty) {
      return const [];
    }
    final pattern = '%$searchTerm%';

    final peopleByNameResponse = await _client
        .from('profiles')
        .select(_profileSelectColumns)
        .ilike('name', pattern)
        .limit(20);
    final peopleByEmailResponse = await _client
        .from('profiles')
        .select(_profileSelectColumns)
        .ilike('email', pattern)
        .limit(20);

    final people = <ChatParticipant>[];
    final seenIds = <String>{};

    void addPeople(Object? response) {
      for (final participant in _participantListFromResponse(response)) {
        if (participant.id.isNotEmpty && seenIds.add(participant.id)) {
          people.add(participant);
        }
      }
    }

    addPeople(peopleByNameResponse);
    addPeople(peopleByEmailResponse);

    final conversationsResponse = await _client
        .from('chat_conversations')
        .select(_conversationSelectColumns)
        .neq('request_status', ChatRequestStatus.pending.name)
        .eq('type', ChatConversationType.group.name)
        .ilike('title', pattern)
        .limit(20);

    final chatMatches = _mapListFromResponse(conversationsResponse)
        .map(ChatConversation.fromMap)
        .map(_participantFromConversation)
        .where((participant) => participant.id.isNotEmpty)
        .where((participant) => seenIds.add(participant.id));

    return [...people, ...chatMatches];
  }

  Future<List<ChatParticipant>> searchEligibleChatPeople(String term) async {
    final normalized = normalizeSearchTerm(term);
    if (normalized.isEmpty) return const [];

    final people = await fetchSuggestedGroupMembers();
    return people.where((person) {
      return person.name.toLowerCase().contains(normalized) ||
          (person.email ?? '').toLowerCase().contains(normalized);
    }).toList();
  }

  Future<bool> isFollowing(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || userId.isEmpty) return false;
    final response = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', userId)
        .maybeSingle();
    return response != null;
  }

  Future<void> followUser(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || userId.isEmpty || currentUserId == userId) {
      return;
    }
    if (await isFollowing(userId)) return;
    try {
      await _client.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': userId,
      });
    } catch (_) {
      if (await isFollowing(userId)) return;
      rethrow;
    }
  }

  Future<List<ChatParticipant>> fetchSuggestedGroupMembers() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      return const [];
    }

    final followerRows = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', currentUserId)
        .limit(25);

    final followingRows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', currentUserId)
        .limit(25);

    final suggestionIds = <String>{
      ..._mapListFromResponse(followerRows)
          .map((row) => _string(row['follower_id'])),
      ..._mapListFromResponse(followingRows)
          .map((row) => _string(row['following_id'])),
    }..removeWhere((id) => id.isEmpty || id == currentUserId);

    final acceptedDirectRows = await _client
        .from('chat_conversations')
        .select('id')
        .eq('type', ChatConversationType.direct.name)
        .eq('request_status', ChatRequestStatus.accepted.name)
        .limit(50);

    final acceptedDirectIds = _mapListFromResponse(acceptedDirectRows)
        .map((row) => _string(row['id']))
        .where((id) => id.isNotEmpty)
        .toList();

    if (acceptedDirectIds.isNotEmpty) {
      final memberRows = await _client
          .from('chat_conversation_members')
          .select('user_id,status')
          .inFilter('conversation_id', acceptedDirectIds)
          .eq('status', ChatMemberStatus.active.name);

      suggestionIds.addAll(
        _mapListFromResponse(memberRows)
            .map((row) => _string(row['user_id']))
            .where((id) => id.isNotEmpty && id != currentUserId),
      );
    }

    return _fetchParticipantsByIds(suggestionIds.toList());
  }

  RealtimeChannel subscribeToChatChanges({
    required String channelName,
    required void Function(PostgresChangePayload payload) onChange,
  }) {
    return _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_conversations',
          callback: onChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_conversation_members',
          callback: onChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: onChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: onChange,
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  static String _stringIdFromRpc(Object? response) {
    String? id;
    if (response is Map) {
      id = (response['id'] ??
              response['conversation_id'] ??
              response['message_id'] ??
              response['notification_id'])
          ?.toString();
    } else {
      id = response?.toString();
    }

    final trimmed = id?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      throw const PostgrestException(message: 'RPC did not return an id.');
    }

    return trimmed;
  }

  Future<List<ChatConversation>> _hydrateConversations(
    List<Map<String, dynamic>> conversationRows,
  ) async {
    if (conversationRows.isEmpty) {
      return const [];
    }

    final conversationIds = conversationRows
        .map((row) => _string(row['id']))
        .where((id) => id.isNotEmpty)
        .toList();
    final currentUserId = _client.auth.currentUser?.id;

    final memberRows = await _fetchConversationMembers(conversationIds);
    final membersByConversation = <String, List<Map<String, dynamic>>>{};
    final profileIds = <String>{};

    for (final member in memberRows) {
      final conversationId = _string(member['conversation_id']);
      final userId = _string(member['user_id']);
      if (conversationId.isEmpty || userId.isEmpty) {
        continue;
      }

      membersByConversation.putIfAbsent(conversationId, () => []).add(member);
      profileIds.add(userId);
    }

    for (final row in conversationRows) {
      profileIds
        ..add(_string(row['requested_by']))
        ..add(_string(row['requested_to']))
        ..add(_string(row['created_by']));
    }
    profileIds.removeWhere((id) => id.isEmpty);

    final profilesById = await _fetchProfilesById(profileIds.toList());
    final lastMessagesByConversation =
        await _fetchLastMessagesByConversation(conversationIds);
    final unreadMessagesByConversation = currentUserId == null
        ? const <String, List<Map<String, dynamic>>>{}
        : await _fetchUnreadMessagesByConversation(
            conversationIds,
            currentUserId,
          );
    final mentionConversationIds = (await _tryFetchUnvisitedMentions())
        .map((mention) => mention.conversationId)
        .toSet();

    return conversationRows.map((row) {
      final conversationId = _string(row['id']);
      final type = _string(row['type']);
      final currentMember = (membersByConversation[conversationId] ?? const [])
          .where((member) => _string(member['user_id']) == currentUserId)
          .firstOrNull;
      final lastReadAt = _dateTimeFromObject(currentMember?['last_read_at']);
      final clearedAt = _dateTimeFromObject(currentMember?['cleared_at']);
      final unreadCount = calculateUnreadConversationCount(
        messages: unreadMessagesByConversation[conversationId] ?? const [],
        currentUserId: currentUserId ?? '',
        lastReadAt: lastReadAt,
        clearedAt: clearedAt,
      );
      final enriched = Map<String, dynamic>.from(row)
        ..['unread_count'] = unreadCount
        ..['has_unvisited_mention'] =
            mentionConversationIds.contains(conversationId)
        ..['last_message_body'] =
            lastMessagesByConversation[conversationId]?['body']
        ..['last_message_at'] =
            lastMessagesByConversation[conversationId]?['created_at']
        ..['created_by_name'] =
            profilesById[_string(row['created_by'])]?['name'];

      if (type == ChatConversationType.direct.name) {
        final otherUserId = _resolveOtherUserId(
          row,
          membersByConversation[conversationId] ?? const [],
          currentUserId,
        );
        final otherProfile = profilesById[otherUserId];

        enriched
          ..['other_user_id'] = otherUserId
          ..['other_user_name'] = otherProfile?['name']
          ..['other_user_avatar_url'] = otherProfile?['avatar_url'];
      }

      return ChatConversation.fromMap(enriched);
    }).toList();
  }

  static List<ChatNotification> _notificationListFromResponse(
    Object? response,
  ) {
    return _mapListFromResponse(response)
        .map(ChatNotification.fromMap)
        .toList();
  }

  static List<ChatParticipant> _participantListFromResponse(Object? response) {
    return _mapListFromResponse(response).map(ChatParticipant.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchConversationMembers(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) {
      return const [];
    }

    final response = await _client
        .from('chat_conversation_members')
        .select('conversation_id,user_id,role,status,last_read_at,cleared_at')
        .inFilter('conversation_id', conversationIds);

    return _mapListFromResponse(response);
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfilesById(
    List<String> profileIds,
  ) async {
    final uniqueIds = profileIds.toSet()..removeWhere((id) => id.isEmpty);
    if (uniqueIds.isEmpty) {
      return const {};
    }

    final response = await _client
        .from('profiles')
        .select(_profileSelectColumns)
        .inFilter('id', uniqueIds.toList());

    return {
      for (final profile in _mapListFromResponse(response))
        if (_string(profile['id']).isNotEmpty) _string(profile['id']): profile,
    };
  }

  Future<List<ChatParticipant>> _fetchParticipantsByIds(
    List<String> profileIds,
  ) async {
    final profilesById = await _fetchProfilesById(profileIds);
    return profileIds
        .where((id) => profilesById.containsKey(id))
        .map((id) => ChatParticipant.fromMap(profilesById[id]!))
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchLastMessagesByConversation(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) {
      return const {};
    }

    final response = await _client
        .from('chat_messages')
        .select(_messageSelectColumns)
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false);

    final messages = <String, Map<String, dynamic>>{};
    for (final row in _mapListFromResponse(response)) {
      final conversationId = _string(row['conversation_id']);
      if (conversationId.isNotEmpty && !messages.containsKey(conversationId)) {
        messages[conversationId] = row;
      }
    }

    return messages;
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      _fetchUnreadMessagesByConversation(
    List<String> conversationIds,
    String currentUserId,
  ) async {
    if (conversationIds.isEmpty || currentUserId.isEmpty) {
      return const {};
    }

    final response = await _client
        .from('chat_messages')
        .select('id, conversation_id, sender_id, created_at, deleted_at')
        .inFilter('conversation_id', conversationIds)
        .neq('sender_id', currentUserId)
        .isFilter('deleted_at', null);

    final messages = <String, List<Map<String, dynamic>>>{};
    for (final row in _mapListFromResponse(response)) {
      final conversationId = _string(row['conversation_id']);
      if (conversationId.isEmpty) continue;
      messages.putIfAbsent(conversationId, () => []).add(row);
    }

    return messages;
  }

  String _requireCurrentUserId() {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw const AuthException('You need to log in to view chat messages.');
    }
    return currentUserId;
  }

  static List<Map<String, dynamic>> _mapListFromResponse(Object? response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    return const [];
  }

  static ChatParticipant _participantFromConversation(
    ChatConversation conversation,
  ) {
    return ChatParticipant(
      id: conversation.otherUserId ?? conversation.id,
      name: conversation.displayTitle,
      avatarUrl: conversation.otherUserAvatarUrl,
    );
  }

  static String _resolveOtherUserId(
    Map<String, dynamic> conversation,
    List<Map<String, dynamic>> members,
    String? currentUserId,
  ) {
    if (currentUserId != null && currentUserId.isNotEmpty) {
      for (final member in members) {
        final userId = _string(member['user_id']);
        if (userId.isNotEmpty && userId != currentUserId) {
          return userId;
        }
      }

      final requestedBy = _string(conversation['requested_by']);
      final requestedTo = _string(conversation['requested_to']);
      if (requestedBy == currentUserId) {
        return requestedTo;
      }
      if (requestedTo == currentUserId) {
        return requestedBy;
      }
    }

    for (final member in members) {
      final userId = _string(member['user_id']);
      if (userId.isNotEmpty) {
        return userId;
      }
    }

    return _string(conversation['requested_to']).isNotEmpty
        ? _string(conversation['requested_to'])
        : _string(conversation['requested_by']);
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static DateTime? _dateTimeFromObject(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static String _safeSearchTerm(String term) {
    return normalizeSearchTerm(
      term.replaceAll(RegExp(r'[%_,(){}.:]'), ' '),
    );
  }

  static String _extensionFor(String fileName, String contentType) {
    final lowerName = fileName.toLowerCase();
    final lowerType = contentType.toLowerCase();
    if (lowerName.endsWith('.png') || lowerType.contains('png')) {
      return '.png';
    }
    if (lowerName.endsWith('.webp') || lowerType.contains('webp')) {
      return '.webp';
    }
    return '.jpg';
  }
}
