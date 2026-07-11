import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/post_card_ratio_preloader.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/post_waterfall_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assigns each post to the currently shorter waterfall column', () {
    final posts = [
      _post('portrait', 'portrait.jpg'),
      _post('landscape-a', 'landscape-a.jpg'),
      _post('landscape-b', 'landscape-b.jpg'),
      _post('square', 'square.jpg'),
    ];

    final columns = buildWaterfallColumns(
      posts,
      ratioForPost: (post) {
        return switch (post.id) {
          'portrait' => PostCardRatioPreloader.portrait34,
          'landscape-a' || 'landscape-b' => PostCardRatioPreloader.landscape43,
          _ => PostCardRatioPreloader.square,
        };
      },
      cardWidth: 160,
      spacing: 12,
    );

    expect(columns.left.map((post) => post.id), ['portrait', 'square']);
    expect(
        columns.right.map((post) => post.id), ['landscape-a', 'landscape-b']);
  });

  test('estimates text-only cards with flexible text surface height', () {
    final post = _post('text-only', null);

    expect(
      estimatePostCardHeight(post, cardWidth: 150),
      lessThan(276),
    );
  });
}

FeedPost _post(String id, String? imageUrl) {
  return FeedPost(
    id: id,
    authorId: 'author',
    authorName: 'Author',
    title: 'Post $id',
    content: 'Content',
    tags: const [],
    moderationStatus: 'approved',
    createdAt: DateTime(2026, 6, 20),
    imageUrls: imageUrl == null ? const [] : [imageUrl],
    likeCount: 0,
    dislikeCount: 0,
    commentCount: 0,
    saveCount: 0,
    shareCount: 0,
    isLiked: false,
    isDisliked: false,
  );
}
