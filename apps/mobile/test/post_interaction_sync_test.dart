import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';
import 'package:cyanzone_mobile/src/features/posts/data/post_interaction_sync.dart';
import 'package:flutter_test/flutter_test.dart';

FeedPost _post(String id) {
  return FeedPost(
    id: id,
    authorId: 'author-$id',
    authorName: 'Author $id',
    title: 'Title $id',
    content: 'Content $id',
    tags: const ['general'],
    moderationStatus: 'approved',
    createdAt: DateTime(2026, 1, 1),
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
  test('deleted result removes the matching post', () {
    final deletedPost = _post('deleted');
    final otherPost = _post('other');
    final update = PostInteractionUpdate(
      postId: deletedPost.id,
      post: deletedPost,
      result: const {'deleted': true},
    );

    expect(update.applyToPosts([deletedPost, otherPost]), [otherPost]);
    expect(
      update.applyToPosts([otherPost], insertIfMissing: true),
      [otherPost],
    );
  });

  test('non-deleted result still replaces the matching post', () {
    final oldPost = _post('same');
    final freshPost = oldPost.copyWith(likeCount: 1);
    final update = PostInteractionUpdate(
      postId: oldPost.id,
      post: freshPost,
      result: const {'deleted': false},
    );

    expect(update.applyToPosts([oldPost]), [freshPost]);
  });
}
