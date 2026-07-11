class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorIsContentCreator = false,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.isLiked,
    required this.isLikedByPostAuthor,
    this.isPinned = false,
    this.parentCommentId,
    this.taggedUserId,
    this.taggedUserName,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final bool authorIsContentCreator;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;
  final bool isLikedByPostAuthor;
  final bool isPinned;
  final String? parentCommentId;
  final String? taggedUserId;
  final String? taggedUserName;

  bool get isReply => parentCommentId != null;

  factory PostComment.fromMap(Map<String, dynamic> map,
      [String? currentUserId]) {
    final profile = (map['profiles'] ?? map['profiles!comments_author_id_fkey'])
        as Map<String, dynamic>?;

    final likeInfo = (map['comment_likes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final likeCount = map['like_count']?[0]?['count'] as int? ?? 0;
    final isLiked = currentUserId != null &&
        likeInfo.any((l) => l['user_id'] == currentUserId);
    final postAuthorId = map['post_author_id'] as String?;
    final isLikedByPostAuthor = postAuthorId != null &&
        likeInfo.any((l) => l['user_id'] == postAuthorId);

    return PostComment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      authorId: map['author_id'] as String,
      authorName: (profile?['name'] as String?) ?? 'CyanZone learner',
      authorIsContentCreator: profile?['is_content_creator'] as bool? ?? false,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      likeCount: likeCount,
      isLiked: isLiked,
      isLikedByPostAuthor: isLikedByPostAuthor,
      isPinned: map['is_pinned'] as bool? ?? false,
      parentCommentId: map['parent_comment_id'] as String?,
      taggedUserId: map['tagged_user_id'] as String?,
      taggedUserName: map['tagged_user_name'] as String?,
    );
  }
}
