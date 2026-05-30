import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_post.dart';

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

class PostsRepository {
  PostsRepository(this._client);

  static const feedSelectColumns =
      'id, author_id, title, content, tags, moderation_status, created_at, '
      'profiles!posts_author_id_fkey(name, avatar_url), '
      'post_images(storage_path, public_url, position)';

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchFeed() async {
    final response = await _client
        .from('posts')
        .select(feedSelectColumns)
        .order('created_at', ascending: false);

    return response.cast<Map<String, dynamic>>().map(FeedPost.fromMap).toList();
  }

  Future<void> createPost(CreatePostInput input) async {
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
    final imageRows = <Map<String, dynamic>>[];

    for (var index = 0; index < input.images.length; index += 1) {
      final image = input.images[index];
      final extension = _extensionFor(image);
      final storagePath =
          '$userId/$postId/${index + 1}-${DateTime.now().microsecondsSinceEpoch}$extension';

      await _client.storage.from('post-images').uploadBinary(
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
        'public_url':
            _client.storage.from('post-images').getPublicUrl(storagePath),
        'position': index + 1,
      });
    }

    if (imageRows.isNotEmpty) {
      await _client.from('post_images').insert(imageRows);
    }
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
