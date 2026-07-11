import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';
import 'package:cyanzone_mobile/src/features/posts/data/post_interaction_sync.dart';
import 'package:cyanzone_mobile/src/features/search/data/search_repository.dart';

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
      'profiles': {'name': 'Ming', 'is_content_creator': true},
      'post_images': [
        {
          'public_url': 'second.jpg',
          'storage_path': 'second-path',
          'position': 2
        },
        {
          'public_url': 'first.jpg',
          'storage_path': 'first-path',
          'position': 1
        },
      ],
    });

    expect(post.authorName, 'Ming');
    expect(post.authorIsContentCreator, isTrue);
    expect(post.tags, ['math', 'study']);
    expect(post.isPending, isTrue);
    expect(post.imageUrls, ['first.jpg', 'second.jpg']);
    expect(post.imageStoragePaths, ['first-path', 'second-path']);
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

  test('identifies whether the current user owns the post', () {
    final post = FeedPost.fromMap({
      'id': 'post-1',
      'author_id': 'user-1',
      'title': 'Science notes',
      'content': 'A short explanation.',
      'tags': <String>[],
      'moderation_status': 'approved',
      'created_at': '2026-05-30T08:00:00Z',
      'profiles': {'name': 'Cyan'},
      'post_images': <Map<String, dynamic>>[],
    });

    expect(post.isOwnedBy('user-1'), isTrue);
    expect(post.isOwnedBy('user-2'), isFalse);
  });

  test('parses interaction state for the provided profile perspective', () {
    final post = FeedPost.fromMap(
      {
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': 'approved',
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
        'likes': [
          {'user_id': 'selected-user', 'reaction_type': 'like'},
          {'user_id': 'viewer-user', 'reaction_type': 'dislike'},
        ],
        'saves': [
          {'user_id': 'selected-user'},
        ],
      },
      'selected-user',
    );

    expect(post.isLiked, isTrue);
    expect(post.isSaved, isTrue);
    expect(post.isDisliked, isFalse);
  });

  test('exports a card update result with current interaction counts', () {
    final hiddenUntil = DateTime.parse('2026-06-25T08:00:00Z');
    final post = FeedPost.fromMap(
      {
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': 'approved',
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
        'likes': [
          {
            'user_id': 'viewer-1',
            'reaction_type': 'dislike',
            'hidden_until': hiddenUntil.toIso8601String(),
          },
        ],
        'saves': [
          {'user_id': 'viewer-1'},
        ],
        'comment_count': [
          {'count': 4},
        ],
        'save_count': [
          {'count': 2},
        ],
        'share_count': [
          {'count': 3},
        ],
      },
      'viewer-1',
    );

    expect(
      post.toCardUpdateResult(),
      containsPair('removeFromDiscovery', isTrue),
    );
    expect(post.toCardUpdateResult(), containsPair('commentCount', 4));
    expect(post.toCardUpdateResult(), containsPair('saveCount', 2));
    expect(post.toCardUpdateResult(), containsPair('shareCount', 3));
    expect(post.toCardUpdateResult(), containsPair('isSaved', isTrue));
  });

  test('search results can patch a post interaction update in place', () {
    final post = FeedPost.fromMap({
      'id': 'post-1',
      'author_id': 'user-1',
      'title': 'Science notes',
      'content': 'A short explanation.',
      'tags': <String>[],
      'moderation_status': 'approved',
      'created_at': '2026-05-30T08:00:00Z',
      'profiles': {'name': 'Cyan'},
      'post_images': <Map<String, dynamic>>[],
    });
    final results = SearchResults(posts: [post], profiles: const []);

    final updated = results.withPostUpdate('post-1', {
      'isLiked': true,
      'likeCount': 1,
      'isSaved': true,
      'saveCount': 1,
      'commentCount': 2,
      'shareCount': 3,
    });

    expect(updated.posts.single.isLiked, isTrue);
    expect(updated.posts.single.likeCount, 1);
    expect(updated.posts.single.isSaved, isTrue);
    expect(updated.posts.single.saveCount, 1);
    expect(updated.posts.single.commentCount, 2);
    expect(updated.posts.single.shareCount, 3);
  });

  test('post interaction update can insert a newly liked post into a list', () {
    final post = FeedPost.fromMap(
      {
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': 'approved',
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
        'likes': [
          {'user_id': 'viewer-1', 'reaction_type': 'like'},
        ],
      },
      'viewer-1',
    );
    final update = PostInteractionUpdate(
      postId: post.id,
      post: post,
      result: post.toCardUpdateResult(),
    );

    final updated = update.applyToPosts(
      const <FeedPost>[],
      insertIfMissing: true,
    );

    expect(updated.single.id, 'post-1');
    expect(updated.single.isLiked, isTrue);
  });

  test('marks current user dislike as active while hidden window is in future',
      () {
    final post = FeedPost.fromMap(
      {
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': 'approved',
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
        'likes': [
          {
            'user_id': 'viewer-1',
            'reaction_type': 'dislike',
            'hidden_until': '2026-06-25T08:00:00Z',
          },
        ],
      },
      'viewer-1',
      DateTime.parse('2026-06-11T08:00:00Z'),
    );

    expect(post.isDisliked, isTrue);
    expect(post.isHiddenFromDiscoveryAt(DateTime.parse('2026-06-11T08:00:00Z')),
        isTrue);
  });

  test('does not hide expired dislikes from discovery', () {
    final post = FeedPost.fromMap(
      {
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': 'approved',
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
        'likes': [
          {
            'user_id': 'viewer-1',
            'reaction_type': 'dislike',
            'hidden_until': '2026-06-10T08:00:00Z',
          },
        ],
      },
      'viewer-1',
      DateTime.parse('2026-06-11T08:00:00Z'),
    );

    expect(post.isDisliked, isTrue);
    expect(post.isHiddenFromDiscoveryAt(DateTime.parse('2026-06-11T08:00:00Z')),
        isFalse);
  });

  test('identifies approved posts for offline profile cache filtering', () {
    FeedPost makePost(String status) {
      return FeedPost.fromMap({
        'id': 'post-$status',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': status,
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
      });
    }

    expect(makePost('approved').isApproved, isTrue);
    expect(makePost('pending').isApproved, isFalse);
    expect(makePost('rejected').isApproved, isFalse);
  });

  test('only approved posts allow social interactions', () {
    FeedPost makePost(String status) {
      return FeedPost.fromMap({
        'id': 'post-$status',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': status,
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': <Map<String, dynamic>>[],
      });
    }

    expect(makePost('approved').allowsInteractions, isTrue);
    expect(makePost('pending').allowsInteractions, isFalse);
    expect(makePost('rejected').allowsInteractions, isFalse);
  });

  test('classifies posts without images as text-only', () {
    FeedPost makePost(List<String> imageUrls) {
      return FeedPost.fromMap({
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Science notes',
        'content': 'A short explanation.',
        'tags': <String>[],
        'moderation_status': 'approved',
        'created_at': '2026-05-30T08:00:00Z',
        'profiles': {'name': 'Cyan'},
        'post_images': [
          for (var index = 0; index < imageUrls.length; index++)
            {'public_url': imageUrls[index], 'position': index},
        ],
      });
    }

    expect(makePost(const []).isTextOnly, isTrue);
    expect(makePost(const ['image.jpg']).isTextOnly, isFalse);
  });
}
