import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_post.dart';
import 'post_comment.dart';
import '../domain/post_submission_repository.dart';

class PickedPostImage {
  const PickedPostImage({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class CreatePostInput {
  const CreatePostInput({
    required this.title,
    required this.content,
    required this.tags,
    required this.images,
  });

  final String title;
  final String content;
  final List<String> tags;
  final List<PickedPostImage> images;
}

class ExistingPostImage {
  const ExistingPostImage({
    required this.storagePath,
    required this.publicUrl,
  });

  final String storagePath;
  final String publicUrl;
}

class UpdatePostInput {
  const UpdatePostInput({
    required this.title,
    required this.content,
    required this.tags,
    required this.keptImages,
    required this.newImages,
  });

  final String title;
  final String content;
  final List<String> tags;
  final List<ExistingPostImage> keptImages;
  final List<PickedPostImage> newImages;
}

class PostsRepository implements PostSubmissionRepository {
  PostsRepository(this._client);

  static const feedSelectColumns =
      'id, author_id, title, content, tags, moderation_status, created_at, '
      'profiles!posts_author_id_fkey(name, avatar_url, is_content_creator), '
      'post_images(storage_path, public_url, position), '
      'likes(user_id, reaction_type, hidden_until), '
      'saves(user_id), '
      'comment_count:comments(count), '
      'save_count:saves(count), '
      'share_count:shares(count)';

  static const reportReasons = [
    'Bullying or harassment',
    'Hate speech or symbols',
    'False information',
    'Self-harm or dangerous behavior',
    'Spam',
    'Inappropriate content',
    'Scam or fraud',
    'Something else',
  ];

  static const savedPostsSelectColumns = 'posts!inner($feedSelectColumns)';
  static const likedPostsSelectColumns = 'posts!inner($feedSelectColumns)';

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchFeed({List<String>? tagFilters}) async {
    var query = _client
        .from('posts')
        .select(feedSelectColumns)
        .eq('moderation_status', 'approved');

    if (tagFilters != null && tagFilters.isNotEmpty) {
      final hasOthers = tagFilters.contains('others');
      final activeFilters = tagFilters.where((t) => t != 'others').toList();

      if (hasOthers && activeFilters.isEmpty) {
        // Only "Others" selected: posts with empty tags
        query = query.eq('tags', '{}');
      } else if (hasOthers && activeFilters.isNotEmpty) {
        // "Others" AND specific tags: (tags is empty) OR (tags overlaps activeFilters)
        query =
            query.or('tags.eq.{},tags.overlaps.{${activeFilters.join(',')}}');
      } else {
        // Only specific tags
        query = query.overlaps('tags', activeFilters);
      }
    }

    final response = await query.order('created_at', ascending: false);

    final userId = _client.auth.currentUser?.id;
    return response
        .cast<Map<String, dynamic>>()
        .map((m) => FeedPost.fromMap(m, userId))
        .where((post) => !post.isHiddenFromDiscovery)
        .toList();
  }

  Future<FeedPost> fetchPostById(String postId) async {
    final response = await _client
        .from('posts')
        .select(feedSelectColumns)
        .eq('id', postId)
        .single();

    return FeedPost.fromMap(
      response,
      _client.auth.currentUser?.id,
    );
  }

  Future<void> toggleLike(String postId) async {
    await _toggleReaction(postId, 'like');
  }

  Future<void> toggleDislike(String postId) async {
    await _toggleReaction(postId, 'dislike');
  }

  Future<void> _toggleReaction(String postId, String reactionType) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in to interact with posts.');
    }

    // Check if already reacted
    final existing = await _client
        .from('likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      if (existing['reaction_type'] == reactionType) {
        // Same reaction, remove it
        await _client
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        // Different reaction, update it
        await _client
            .from('likes')
            .update({
              'reaction_type': reactionType,
              'hidden_until': reactionType == 'dislike'
                  ? _dislikeHiddenUntil().toIso8601String()
                  : null,
            })
            .eq('post_id', postId)
            .eq('user_id', userId);
      }
    } else {
      await _client.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
        'reaction_type': reactionType,
        'hidden_until': reactionType == 'dislike'
            ? _dislikeHiddenUntil().toIso8601String()
            : null,
      });
    }
  }

  DateTime _dislikeHiddenUntil() {
    return DateTime.now().toUtc().add(const Duration(days: 14));
  }

  Future<void> toggleSave(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in to save posts.');
    }

    final existing = await _client
        .from('saves')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('saves')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      await _client.from('saves').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<List<FeedPost>> searchPosts(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return [];

    final response = await _client
        .from('posts')
        .select(feedSelectColumns)
        .eq('moderation_status', 'approved')
        .or('title.ilike.%$searchTerm%,content.ilike.%$searchTerm%')
        .order('created_at', ascending: false);

    final userId = _client.auth.currentUser?.id;
    return response
        .cast<Map<String, dynamic>>()
        .map((m) => FeedPost.fromMap(m, userId))
        .where((post) => !post.isHiddenFromDiscovery)
        .toList();
  }

  Future<List<FeedPost>> fetchFollowingPosts() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 1. Get IDs of people the user follows
    final followingResponse = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    final followingIds = followingResponse
        .cast<Map<String, dynamic>>()
        .map((row) => row['following_id'] as String)
        .toList();

    if (followingIds.isEmpty) return [];

    // 2. Fetch posts from those authors
    final postsResponse = await _client
        .from('posts')
        .select(feedSelectColumns)
        .inFilter('author_id', followingIds)
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false);

    return postsResponse
        .cast<Map<String, dynamic>>()
        .map((m) => FeedPost.fromMap(m, userId))
        .where((post) => !post.isHiddenFromDiscovery)
        .toList();
  }

  Future<List<FeedPost>> fetchUserPosts(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    var query =
        _client.from('posts').select(feedSelectColumns).eq('author_id', userId);

    if (currentUserId == userId) {
      query = query.neq('moderation_status', 'removed');
    } else {
      query = query.eq('moderation_status', 'approved');
    }

    final response = await query.order('created_at', ascending: false);

    return response
        .cast<Map<String, dynamic>>()
        .map((m) => FeedPost.fromMap(m, currentUserId))
        .toList();
  }

  Future<List<FeedPost>> fetchSavedPosts({String? userId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return [];

    final response = await _client
        .from('saves')
        .select(savedPostsSelectColumns)
        .eq('user_id', targetUserId)
        .order('created_at', ascending: false);

    return response
        .cast<Map<String, dynamic>>()
        .map((row) => FeedPost.fromMap(
              row['posts'] as Map<String, dynamic>,
              targetUserId,
            ))
        .toList();
  }

  Future<List<FeedPost>> fetchLikedPosts({String? userId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return [];

    final response = await _client
        .from('likes')
        .select(likedPostsSelectColumns)
        .eq('user_id', targetUserId)
        .eq('reaction_type', 'like')
        .order('created_at', ascending: false);

    return response
        .cast<Map<String, dynamic>>()
        .map((row) => FeedPost.fromMap(
              row['posts'] as Map<String, dynamic>,
              targetUserId,
            ))
        .toList();
  }

  Future<void> recordShare(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('shares').insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  Future<void> removePost(String postId) async {
    final imageRows = await _client
        .from('post_images')
        .select('storage_path')
        .eq('post_id', postId);
    final storagePaths = imageRows
        .cast<Map<String, dynamic>>()
        .map((row) => row['storage_path'] as String?)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();

    await _client
        .from('posts')
        .update({'moderation_status': 'removed'}).eq('id', postId);

    if (storagePaths.isNotEmpty) {
      await _client.from('post_images').delete().eq('post_id', postId);
      await _client.storage.from('images').remove(storagePaths);
    }
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    final response = await _client
        .from('comments')
        .select('*, posts!comments_post_id_fkey(author_id), '
            'profiles!comments_author_id_fkey(name, avatar_url, is_content_creator), '
            'comment_likes(user_id), '
            'like_count:comment_likes(count)')
        .eq('post_id', postId)
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: true);

    final userId = _client.auth.currentUser?.id;
    return response.cast<Map<String, dynamic>>().map((m) {
      final post = m['posts'] as Map<String, dynamic>?;
      return PostComment.fromMap(
        {
          ...m,
          'post_author_id': post?['author_id'],
        },
        userId,
      );
    }).toList();
  }

  Future<void> toggleCommentLike(String commentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in to like comments.');
    }

    // Check if already liked
    final existing = await _client
        .from('comment_likes')
        .select()
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } else {
      await _client.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
    }
  }

  @override
  Future<String> createComment(
    String postId,
    String content, {
    String? parentCommentId,
    String? taggedUserId,
    String? taggedUserName,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in to comment.');
    }

    final row = await _client
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': userId,
          'content': content.trim(),
          if (parentCommentId != null) 'parent_comment_id': parentCommentId,
          if (taggedUserId != null) 'tagged_user_id': taggedUserId,
          if (taggedUserName != null) 'tagged_user_name': taggedUserName,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('comments')
        .update({'moderation_status': 'removed'}).eq('id', commentId);
  }

  Future<void> toggleCommentPin(String commentId, {required bool pin}) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('comments').update({
      'is_pinned': pin,
      'pinned_by': pin ? userId : null,
      'pinned_at': pin ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', commentId);
  }

  Future<void> createReport({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in to report content.');
    }

    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    });
  }

  @override
  Future<String> createPost(CreatePostInput input) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in before posting.');
    }

    final post = await _client
        .from('posts')
        .insert({
          'author_id': userId,
          'title': input.title.trim(),
          'content': input.content.trim(),
          'tags': input.tags,
        })
        .select('id')
        .single();

    final postId = post['id'] as String;
    final imageRows = await _uploadPostImages(
      userId: userId,
      postId: postId,
      images: input.images,
      startPosition: 1,
    );

    if (imageRows.isNotEmpty) {
      await _client.from('post_images').insert(imageRows);
    }
    return postId;
  }

  @override
  Future<String> updatePost(String postId, UpdatePostInput input) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You need to log in before editing posts.');
    }

    final currentRows = await _client
        .from('post_images')
        .select('storage_path, public_url, position')
        .eq('post_id', postId);
    final currentStoragePaths = currentRows
        .cast<Map<String, dynamic>>()
        .map((row) => row['storage_path'] as String)
        .toSet();
    final keptStoragePaths =
        input.keptImages.map((image) => image.storagePath).toSet();
    final removedStoragePaths =
        currentStoragePaths.difference(keptStoragePaths).toList();

    if (removedStoragePaths.isNotEmpty) {
      await _client
          .from('post_images')
          .delete()
          .eq('post_id', postId)
          .inFilter('storage_path', removedStoragePaths);
    }

    for (var index = 0; index < input.keptImages.length; index += 1) {
      await _client
          .from('post_images')
          .update({
            'public_url': input.keptImages[index].publicUrl,
            'position': index + 1,
          })
          .eq('post_id', postId)
          .eq('storage_path', input.keptImages[index].storagePath);
    }

    final newImageRows = await _uploadPostImages(
      userId: userId,
      postId: postId,
      images: input.newImages,
      startPosition: input.keptImages.length + 1,
    );

    if (newImageRows.isNotEmpty) {
      await _client.from('post_images').insert(newImageRows);
    }

    await _client
        .from('posts')
        .update({
          'title': input.title.trim(),
          'content': input.content.trim(),
          'tags': input.tags,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId)
        .eq('author_id', userId);

    if (removedStoragePaths.isNotEmpty) {
      await _client.storage.from('images').remove(removedStoragePaths);
    }
    return postId;
  }

  Future<List<Map<String, dynamic>>> _uploadPostImages({
    required String userId,
    required String postId,
    required List<PickedPostImage> images,
    required int startPosition,
  }) async {
    final imageRows = <Map<String, dynamic>>[];

    for (var index = 0; index < images.length; index += 1) {
      final image = images[index];
      final position = startPosition + index;
      final extension = _extensionFor(image);
      final storagePath =
          '$userId/$postId/$position-${DateTime.now().microsecondsSinceEpoch}$extension';

      await _client.storage.from('images').uploadBinary(
            storagePath,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: false,
            ),
          );

      imageRows.add({
        'post_id': postId,
        'storage_path': storagePath,
        'public_url': _client.storage.from('images').getPublicUrl(storagePath),
        'mime_type': image.contentType,
        'position': position,
      });
    }

    return imageRows;
  }

  String _extensionFor(PickedPostImage image) {
    final lowerName = image.name.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return '.png';
    }
    if (lowerName.endsWith('.webp')) {
      return '.webp';
    }
    return '.jpg';
  }
}
