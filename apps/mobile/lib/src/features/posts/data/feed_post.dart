class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.tags,
    required this.moderationStatus,
    required this.createdAt,
    required this.imageUrls,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final List<String> tags;
  final String moderationStatus;
  final DateTime createdAt;
  final List<String> imageUrls;

  bool get isPending => moderationStatus == 'pending';

  factory FeedPost.fromMap(Map<String, dynamic> map) {
    final profile = (map['profiles'] ?? map['profiles!posts_author_id_fkey'])
        as Map<String, dynamic>?;
    final images = (map['post_images'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort(
        (a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0),
      );

    return FeedPost(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      authorName: (profile?['name'] as String?) ?? 'CyanZone learner',
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
    );
  }
}
