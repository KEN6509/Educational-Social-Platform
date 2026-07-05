import 'dart:convert';

enum ChatConversationType { direct, group }

enum ChatRequestStatus { none, pending, accepted, blocked }

enum ChatMemberStatus { active, pending, left, removed }

enum NotificationSection { activity, system, followers, chat }

enum NotificationActivityGroup { likesFavorites, comments, mentions, other }

class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.role,
    this.isSelected = false,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? role;
  final bool isSelected;

  bool get isAdmin => role == 'owner';

  factory ChatParticipant.fromMap(Map<String, dynamic> map) {
    return ChatParticipant(
      id: _stringValue(map['id']),
      name: _stringValue(map['name']),
      email: _nullableStringValue(map['email']),
      avatarUrl: _nullableStringValue(
        map['avatar_url'] ?? map['avatarUrl'],
      ),
      role: _nullableStringValue(map['role']),
      isSelected: _boolValue(
        map['is_selected'] ?? map['isSelected'],
      ),
    );
  }

  ChatParticipant copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? role,
    bool? isSelected,
  }) {
    return ChatParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.requestStatus,
    required this.unreadCount,
    this.title,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatarUrl,
    this.lastMessageBody,
    this.lastMessageAt,
    this.createdBy,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final ChatConversationType type;
  final ChatRequestStatus requestStatus;
  final int unreadCount;
  final String? title;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatarUrl;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;

  bool get isGroup => type == ChatConversationType.group;

  bool get isRequest => requestStatus == ChatRequestStatus.pending;

  String get displayTitle {
    final explicitTitle = _trimmedOrNull(title);
    if (explicitTitle != null) {
      return explicitTitle;
    }

    final otherName = _trimmedOrNull(otherUserName);
    if (otherName != null) {
      return otherName;
    }

    return isGroup ? 'Group chat' : 'Chat';
  }

  ChatConversation copyWith({
    String? id,
    ChatConversationType? type,
    ChatRequestStatus? requestStatus,
    int? unreadCount,
    String? title,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatarUrl,
    String? lastMessageBody,
    DateTime? lastMessageAt,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      requestStatus: requestStatus ?? this.requestStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      title: title ?? this.title,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatarUrl: otherUserAvatarUrl ?? this.otherUserAvatarUrl,
      lastMessageBody: lastMessageBody ?? this.lastMessageBody,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: _stringValue(map['id']),
      type: _parseEnum(
        map['type'],
        ChatConversationType.values,
        ChatConversationType.direct,
      ),
      requestStatus: _parseEnum(
        map['request_status'] ?? map['requestStatus'],
        ChatRequestStatus.values,
        ChatRequestStatus.none,
      ),
      unreadCount: _intValue(map['unread_count'] ?? map['unreadCount']),
      title: _nullableStringValue(map['title']),
      otherUserId: _nullableStringValue(
        map['other_user_id'] ?? map['otherUserId'],
      ),
      otherUserName: _nullableStringValue(
        map['other_user_name'] ?? map['otherUserName'],
      ),
      otherUserAvatarUrl: _nullableStringValue(
        map['other_user_avatar_url'] ?? map['otherUserAvatarUrl'],
      ),
      lastMessageBody: _nullableStringValue(
        map['last_message_body'] ?? map['lastMessageBody'],
      ),
      lastMessageAt: _dateTimeValue(
        map['last_message_at'] ?? map['lastMessageAt'],
      ),
      createdBy: _nullableStringValue(map['created_by'] ?? map['createdBy']),
      createdByName: _nullableStringValue(
        map['created_by_name'] ?? map['createdByName'],
      ),
      createdAt: _dateTimeValue(map['created_at'] ?? map['createdAt']),
    );
  }
}

class ChatMessage {
  static const imagePrefix = 'cz-image:';
  static const multiImagePrefix = 'cz-images:';

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.deletedAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final DateTime? deletedAt;
  final String? senderName;
  final String? senderAvatarUrl;

  bool get isDeleted => deletedAt != null;

  bool get hasImage => !isDeleted && imageUrls.isNotEmpty;

  String? get imageUrl {
    final urls = imageUrls;
    return urls.isEmpty ? null : urls.first;
  }

  List<String> get imageUrls {
    if (isDeleted) return const [];
    return imageUrlsFor(body);
  }

  List<String> get imageStoragePaths {
    if (isDeleted) return const [];
    return imageStoragePathsFor(body);
  }

  List<double> get imageAspectRatios {
    if (isDeleted) return const [];
    return imageAspectRatiosFor(body);
  }

  static List<String> imageUrlsFor(String value) {
    return _imageEntriesFor(value)
        .map((entry) => entry.url)
        .where((url) => url.isNotEmpty)
        .toList();
  }

  static List<String> imageStoragePathsFor(String value) {
    return _imageEntriesFor(value)
        .map((entry) => entry.path)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();
  }

  static List<double> imageAspectRatiosFor(String value) {
    return _imageEntriesFor(value)
        .map((entry) => entry.aspectRatio)
        .whereType<double>()
        .where((ratio) => ratio > 0)
        .toList();
  }

  static List<_ChatImageEntry> _imageEntriesFor(String value) {
    if (value.startsWith(imagePrefix)) {
      final raw = value.substring(imagePrefix.length).trim();
      final entry = _imageEntryFromPayload(raw);
      return entry == null ? const [] : [entry];
    }

    if (value.startsWith(multiImagePrefix)) {
      final raw = value.substring(multiImagePrefix.length).trim();
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return const [];
        return decoded
            .map(_imageEntryFromPayload)
            .whereType<_ChatImageEntry>()
            .toList();
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  static _ChatImageEntry? _imageEntryFromPayload(Object? payload) {
    if (payload is String) {
      final raw = payload.trim();
      if (raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return _imageEntryFromPayload(decoded);
      } catch (_) {}
      return _ChatImageEntry(url: raw);
    }

    if (payload is Map) {
      final url = _nullableStringValue(payload['url']) ?? '';
      final path = _nullableStringValue(payload['path']);
      final aspectRatio = _nullableDoubleValue(payload['aspectRatio']);
      if (url.isEmpty) return null;
      return _ChatImageEntry(
        url: url,
        path: path,
        aspectRatio: aspectRatio,
      );
    }

    return null;
  }

  String get displayBody => hasImage ? 'Photo' : body;

  static bool bodyHasImage(String value) {
    return value.startsWith(imagePrefix) || value.startsWith(multiImagePrefix);
  }

  static String displayBodyFor(String value) {
    return bodyHasImage(value) ? 'Photo' : value;
  }

  factory ChatMessage.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final senderId = _stringValue(map['sender_id'] ?? map['senderId']);

    return ChatMessage(
      id: _stringValue(map['id']),
      conversationId: _stringValue(
        map['conversation_id'] ?? map['conversationId'],
      ),
      senderId: senderId,
      body: _stringValue(map['body']).trim(),
      createdAt: _dateTimeValue(map['created_at'] ?? map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isMine: senderId == currentUserId,
      deletedAt: _dateTimeValue(map['deleted_at'] ?? map['deletedAt']),
      senderName: _nullableStringValue(
        (map['profiles'] as Map?)?['name'] ??
            map['sender_name'] ??
            map['senderName'],
      ),
      senderAvatarUrl: _nullableStringValue(
        (map['profiles'] as Map?)?['avatar_url'] ??
            map['sender_avatar_url'] ??
            map['senderAvatarUrl'],
      ),
    );
  }
}

class _ChatImageEntry {
  const _ChatImageEntry({
    required this.url,
    this.path,
    this.aspectRatio,
  });

  final String url;
  final String? path;
  final double? aspectRatio;
}

class ChatNotification {
  const ChatNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.actorId,
    this.actorName,
    this.actorAvatarUrl,
    this.postId,
    this.commentId,
    this.postFirstImageUrl,
    this.postAuthorAvatarUrl,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? actorId;
  final String? actorName;
  final String? actorAvatarUrl;
  final String? postId;
  final String? commentId;
  final String? postFirstImageUrl;
  final String? postAuthorAvatarUrl;

  bool get isUnread => readAt == null;

  NotificationSection get section {
    switch (type) {
      case 'system':
        return NotificationSection.system;
      case 'new_follower':
        return NotificationSection.followers;
      case 'chat_message':
        return NotificationSection.chat;
      default:
        return NotificationSection.activity;
    }
  }

  NotificationActivityGroup get activityGroup {
    switch (type) {
      case 'like':
      case 'favorite':
        return NotificationActivityGroup.likesFavorites;
      case 'comment':
      case 'comment_reply':
      case 'comment_like':
        return NotificationActivityGroup.comments;
      case 'mention':
        return NotificationActivityGroup.mentions;
      default:
        return NotificationActivityGroup.other;
    }
  }

  String get activityLabel {
    switch (type) {
      case 'like':
        return 'liked your post';
      case 'favorite':
        return 'saved your post';
      case 'comment':
        return 'commented on your post';
      case 'comment_reply':
        return 'replied to your comment';
      case 'comment_like':
        return 'liked your comment';
      case 'mention':
        return 'mentioned you';
      default:
        return body;
    }
  }

  factory ChatNotification.fromMap(Map<String, dynamic> map) {
    final post = (map['posts'] ?? map['posts!notifications_post_id_fkey'])
        as Map<String, dynamic>?;
    final postImages = (post?['post_images'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort(
        (a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0),
      );
    final postAuthorProfile =
        (post?['profiles'] ?? post?['profiles!posts_author_id_fkey'])
            as Map<String, dynamic>?;

    return ChatNotification(
      id: _stringValue(map['id']),
      type: _stringValue(map['type']),
      title: _stringValue(map['title']),
      body: _stringValue(map['body']),
      createdAt: _dateTimeValue(map['created_at'] ?? map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: _dateTimeValue(map['read_at'] ?? map['readAt']),
      actorId: _nullableStringValue(map['actor_id'] ?? map['actorId']),
      actorName: _nullableStringValue(
        (map['profiles'] as Map?)?['name'] ?? map['actor_name'],
      ),
      actorAvatarUrl: _nullableStringValue(
        (map['profiles'] as Map?)?['avatar_url'] ?? map['actor_avatar_url'],
      ),
      postId: _nullableStringValue(map['post_id'] ?? map['postId']),
      commentId: _nullableStringValue(map['comment_id'] ?? map['commentId']),
      postFirstImageUrl: _nullableStringValue(
        postImages.isEmpty
            ? map['post_first_image_url']
            : postImages.first['public_url'],
      ),
      postAuthorAvatarUrl: _nullableStringValue(
        postAuthorProfile?['avatar_url'] ?? map['post_author_avatar_url'],
      ),
    );
  }
}

T _parseEnum<T extends Enum>(
  Object? value,
  List<T> values,
  T fallback,
) {
  final normalized = _stringValue(value).trim().toLowerCase();
  if (normalized.isEmpty) {
    return fallback;
  }

  for (final enumValue in values) {
    if (enumValue.name == normalized) {
      return enumValue;
    }
  }

  return fallback;
}

DateTime? _dateTimeValue(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }

  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }

  return parsed.isUtc ? parsed.toLocal() : parsed;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }

  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

String _stringValue(Object? value) => value?.toString() ?? '';

String? _nullableStringValue(Object? value) =>
    _trimmedOrNull(_stringValue(value));

double? _nullableDoubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_stringValue(value));
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
