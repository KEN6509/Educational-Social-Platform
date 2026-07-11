class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorIsContentCreator = false,
    this.authorAvatarUrl,
    required this.title,
    required this.content,
    required this.tags,
    required this.moderationStatus,
    required this.createdAt,
    required this.imageUrls,
    this.imageStoragePaths = const [],
    required this.likeCount,
    required this.dislikeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.isLiked,
    required this.isDisliked,
    this.dislikeHiddenUntil,
    this.isSaved = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final bool authorIsContentCreator;
  final String? authorAvatarUrl;
  final String title;
  final String content;
  final List<String> tags;
  final String moderationStatus;
  final DateTime createdAt;
  final List<String> imageUrls;
  final List<String> imageStoragePaths;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final bool isLiked;
  final bool isDisliked;
  final DateTime? dislikeHiddenUntil;
  final bool isSaved;

  bool get isPending => moderationStatus == 'pending';
  bool get isApproved => moderationStatus == 'approved';
  bool get isRejected => moderationStatus == 'rejected';
  bool get isTextOnly => imageUrls.isEmpty;
  bool get allowsInteractions => isApproved;
  bool get isHiddenFromDiscovery {
    return isHiddenFromDiscoveryAt(DateTime.now());
  }

  bool isHiddenFromDiscoveryAt(DateTime now) {
    final hiddenUntil = dislikeHiddenUntil;
    if (!isDisliked || hiddenUntil == null) return false;
    return hiddenUntil.isAfter(now);
  }

  bool isOwnedBy(String? userId) => userId != null && authorId == userId;

  Map<String, dynamic> toCardUpdateResult({
    bool deleted = false,
  }) {
    return {
      'deleted': deleted,
      'isLiked': isLiked,
      'likeCount': likeCount,
      'isDisliked': isDisliked,
      'dislikeCount': dislikeCount,
      'isSaved': isSaved,
      'saveCount': saveCount,
      'shareCount': shareCount,
      'commentCount': commentCount,
      'dislikeHiddenUntil': dislikeHiddenUntil,
      'removeFromDiscovery': isDisliked,
    };
  }

  FeedPost copyWith({
    int? likeCount,
    int? dislikeCount,
    int? commentCount,
    int? saveCount,
    int? shareCount,
    bool? isLiked,
    bool? isDisliked,
    DateTime? dislikeHiddenUntil,
    bool? isSaved,
  }) {
    return FeedPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorIsContentCreator: authorIsContentCreator,
      authorAvatarUrl: authorAvatarUrl,
      title: title,
      content: content,
      tags: tags,
      moderationStatus: moderationStatus,
      createdAt: createdAt,
      imageUrls: imageUrls,
      imageStoragePaths: imageStoragePaths,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      shareCount: shareCount ?? this.shareCount,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      dislikeHiddenUntil: dislikeHiddenUntil ?? this.dislikeHiddenUntil,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  factory FeedPost.fromMap(
    Map<String, dynamic> map, [
    String? currentUserId,
    DateTime? now,
  ]) {
    final profile = (map['profiles'] ?? map['profiles!posts_author_id_fkey'])
        as Map<String, dynamic>?;
    final images = (map['post_images'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort(
        (a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0),
      );

    final likeInfo =
        (map['likes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final likeCount =
        likeInfo.where((l) => l['reaction_type'] == 'like').length;
    final dislikeCount =
        likeInfo.where((l) => l['reaction_type'] == 'dislike').length;

    final commentCount = map['comment_count']?[0]?['count'] as int? ?? 0;
    final saveCount = map['save_count']?[0]?['count'] as int? ?? 0;
    final shareCount = map['share_count']?[0]?['count'] as int? ?? 0;

    // Check if the current user has liked or disliked
    final isLiked = currentUserId != null &&
        likeInfo.any((l) =>
            l['user_id'] == currentUserId && l['reaction_type'] == 'like');
    final isDisliked = currentUserId != null &&
        likeInfo.any((l) =>
            l['user_id'] == currentUserId && l['reaction_type'] == 'dislike');
    final dislikeHiddenUntil = _currentUserDislikeHiddenUntil(
      likeInfo,
      currentUserId,
    );

    final saveInfo =
        (map['saves'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final isSaved = currentUserId != null &&
        saveInfo.any((s) => s['user_id'] == currentUserId);

    return FeedPost(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorName: (profile?['name'] as String?) ?? 'CyanZone learner',
      authorIsContentCreator: profile?['is_content_creator'] as bool? ?? false,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      title: map['title'] as String,
      content: map['content'] as String,
      tags: (map['tags'] as List<dynamic>? ?? []).cast<String>(),
      moderationStatus: map['moderation_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      imageUrls: images
          .map((image) => image['public_url'] as String?)
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList(),
      imageStoragePaths: images
          .map((image) => image['storage_path'] as String?)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toList(),
      likeCount: likeCount,
      dislikeCount: dislikeCount,
      commentCount: commentCount,
      saveCount: saveCount,
      shareCount: shareCount,
      isLiked: isLiked,
      isDisliked: isDisliked,
      dislikeHiddenUntil: dislikeHiddenUntil,
      isSaved: isSaved,
    );
  }

  static DateTime? _currentUserDislikeHiddenUntil(
    List<Map<String, dynamic>> likeInfo,
    String? currentUserId,
  ) {
    if (currentUserId == null) return null;

    for (final like in likeInfo) {
      if (like['user_id'] != currentUserId ||
          like['reaction_type'] != 'dislike') {
        continue;
      }
      final rawHiddenUntil = like['hidden_until'] as String?;
      if (rawHiddenUntil == null || rawHiddenUntil.isEmpty) return null;
      return DateTime.parse(rawHiddenUntil).toLocal();
    }

    return null;
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_is_content_creator': authorIsContentCreator,
      'author_avatar_url': authorAvatarUrl,
      'title': title,
      'content': content,
      'tags': tags,
      'moderation_status': moderationStatus,
      'created_at': createdAt.toIso8601String(),
      'image_urls': imageUrls,
      'image_storage_paths': imageStoragePaths,
      'like_count': likeCount,
      'dislike_count': dislikeCount,
      'comment_count': commentCount,
      'save_count': saveCount,
      'share_count': shareCount,
      'is_liked': isLiked,
      'is_disliked': isDisliked,
      'dislike_hidden_until': dislikeHiddenUntil?.toIso8601String(),
      'is_saved': isSaved,
    };
  }

  factory FeedPost.fromCacheMap(Map<String, dynamic> map) {
    return FeedPost(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorName: map['author_name'] as String? ?? 'CyanZone learner',
      authorIsContentCreator:
          map['author_is_content_creator'] as bool? ?? false,
      authorAvatarUrl: map['author_avatar_url'] as String?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>? ?? []).cast<String>(),
      moderationStatus: map['moderation_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      imageUrls: (map['image_urls'] as List<dynamic>? ?? []).cast<String>(),
      imageStoragePaths:
          (map['image_storage_paths'] as List<dynamic>? ?? []).cast<String>(),
      likeCount: map['like_count'] as int? ?? 0,
      dislikeCount: map['dislike_count'] as int? ?? 0,
      commentCount: map['comment_count'] as int? ?? 0,
      saveCount: map['save_count'] as int? ?? 0,
      shareCount: map['share_count'] as int? ?? 0,
      isLiked: map['is_liked'] as bool? ?? false,
      isDisliked: map['is_disliked'] as bool? ?? false,
      dislikeHiddenUntil: (map['dislike_hidden_until'] as String?) == null
          ? null
          : DateTime.parse(map['dislike_hidden_until'] as String).toLocal(),
      isSaved: map['is_saved'] as bool? ?? false,
    );
  }
}
