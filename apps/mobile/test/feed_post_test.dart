import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';

void main() {
  test('parses feed post images in position order', () {
    final post = FeedPost.fromMap({
      'id': 'post-1',
      'author_id': 'user-1',
      'title': 'Algebra basics',
      'content': 'A short explanation.',
      'tags': ['math', 'study'],
      'moderation_status': 'pending',
      'created_at': '2026-05-30T08:00:00Z',
      'profiles': {'name': 'Ming'},
      'post_images': [
        {'public_url': 'second.jpg', 'position': 2},
        {'public_url': 'first.jpg', 'position': 1},
      ],
    });

    expect(post.authorName, 'Ming');
    expect(post.tags, ['math', 'study']);
    expect(post.isPending, isTrue);
    expect(post.imageUrls, ['first.jpg', 'second.jpg']);
  });

  test('parses author profile from explicit Supabase relationship alias', () {
    final post = FeedPost.fromMap({
      'id': 'post-1',
      'author_id': 'user-1',
      'title': 'Science notes',
      'content': 'A short explanation.',
      'tags': <String>[],
      'moderation_status': 'approved',
      'created_at': '2026-05-30T08:00:00Z',
      'profiles!posts_author_id_fkey': {'name': 'Cyan'},
      'post_images': <Map<String, dynamic>>[],
    });

    expect(post.authorName, 'Cyan');
  });
}
