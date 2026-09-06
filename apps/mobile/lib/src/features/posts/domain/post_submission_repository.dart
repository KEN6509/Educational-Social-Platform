import '../data/posts_repository.dart';

abstract interface class PostSubmissionRepository {
  Future<String> createPost(CreatePostInput input);

  Future<String> updatePost(String postId, UpdatePostInput input);

  Future<String> createComment(
    String postId,
    String content, {
    String? parentCommentId,
    String? taggedUserId,
    String? taggedUserName,
  });
}
