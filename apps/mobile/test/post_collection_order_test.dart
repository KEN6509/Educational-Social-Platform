import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';
import 'package:cyanzone_mobile/src/features/posts/data/feed_mode.dart';
import 'package:cyanzone_mobile/src/features/posts/data/post_collection_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

FeedPost _post(
  String id, {
  required String status,
  required DateTime createdAt,
}) {
  return FeedPost(
    id: id,
    authorId: 'author',
    authorName: 'Author',
    title: id,
    content: id,
    tags: const [],
    moderationStatus: status,
    createdAt: createdAt,
    imageUrls: const [],
    likeCount: 0,
    dislikeCount: 0,
    commentCount: 0,
    saveCount: 0,
    shareCount: 0,
    isLiked: false,
    isDisliked: false,
  );
}

void main() {
  final newest = DateTime(2026, 9, 11, 12);
  final older = DateTime(2026, 9, 10, 12);

  test('profile ordering puts all non-approved posts first', () {
    final posts = [
      _post('approved-new', status: 'approved', createdAt: newest),
      _post('pending-old', status: 'pending', createdAt: older),
      _post('rejected-new', status: 'rejected', createdAt: newest),
    ];

    expect(
      orderProfilePosts(posts).map((post) => post.id).toList(),
      ['rejected-new', 'pending-old', 'approved-new'],
    );
  });

  test('newest ordering uses post id to keep equal timestamps stable', () {
    final posts = [
      _post('a', status: 'approved', createdAt: newest),
      _post('c', status: 'approved', createdAt: older),
      _post('b', status: 'approved', createdAt: newest),
    ];

    expect(
      orderNewestPosts(posts).map((post) => post.id).toList(),
      ['b', 'a', 'c'],
    );
  });

  test('following stays newest first until a manual rearrangement', () {
    final posts = [
      _post('newest', status: 'approved', createdAt: newest),
      _post('older', status: 'approved', createdAt: older),
    ];

    expect(
      arrangeHomePosts(posts, mode: FeedMode.following)
          .map((post) => post.id)
          .toList(),
      ['newest', 'older'],
    );
    expect(
      arrangeHomePosts(
        posts,
        mode: FeedMode.following,
        rearrangeFollowing: true,
        random: Random(1),
      ).map((post) => post.id).toSet(),
      {'newest', 'older'},
    );
  });
}
