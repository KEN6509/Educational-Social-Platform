import 'package:flutter/foundation.dart';

import 'feed_post.dart';

class PostInteractionUpdate {
  const PostInteractionUpdate({
    required this.postId,
    required this.post,
    required this.result,
  });

  final String postId;
  final FeedPost post;
  final Map<String, dynamic> result;

  bool get isDeleted => result['deleted'] == true;

  List<FeedPost> applyToPosts(
    List<FeedPost> posts, {
    bool insertIfMissing = false,
  }) {
    if (isDeleted) {
      return posts.where((item) => item.id != postId).toList();
    }

    var found = false;
    final updated = posts.map((item) {
      if (item.id != postId) return item;
      found = true;
      return post;
    }).toList();

    if (!found && insertIfMissing) {
      return [post, ...updated];
    }
    return found ? updated : posts;
  }
}

class PostInteractionSync {
  PostInteractionSync._();

  static final latest = ValueNotifier<PostInteractionUpdate?>(null);

  static void publish({
    required String postId,
    required FeedPost post,
    required Map<String, dynamic> result,
  }) {
    latest.value = PostInteractionUpdate(
      postId: postId,
      post: post,
      result: result,
    );
  }
}
