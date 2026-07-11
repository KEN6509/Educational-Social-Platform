import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:cyanzone_mobile/src/features/posts/data/post_comment.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/comment_date_formatter.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/comment_reply_visibility.dart';

void main() {
  test('parses reply relationship from parent comment id', () {
    final comment = PostComment.fromMap({
      'id': 'reply-1',
      'post_id': 'post-1',
      'author_id': 'user-2',
      'content': 'Totally agree.',
      'created_at': '2026-06-10T08:00:00Z',
      'parent_comment_id': 'comment-1',
      'tagged_user_id': 'user-1',
      'tagged_user_name': 'Old Name',
      'profiles': {'name': 'Cyan', 'is_content_creator': true},
      'comment_likes': <Map<String, dynamic>>[],
      'like_count': [
        {'count': 0},
      ],
    });

    expect(comment.parentCommentId, 'comment-1');
    expect(comment.isReply, isTrue);
    expect(comment.authorIsContentCreator, isTrue);
    expect(comment.taggedUserId, 'user-1');
    expect(comment.taggedUserName, 'Old Name');
  });

  test('formats hidden reply count like Instagram-style thread controls', () {
    expect(formatHiddenRepliesLabel(1), 'View 1 more reply');
    expect(formatHiddenRepliesLabel(3), 'View 3 more replies');
  });

  test('formats post and comment dates using social relative labels', () {
    final now = DateTime(2026, 6, 20, 12);

    expect(formatPostDate(DateTime(2026, 6, 18, 12), now), '2d ago');
    expect(formatPostDate(DateTime(2026, 6, 20, 8), now), '4h ago');
    expect(formatPostDate(DateTime(2026, 6, 20, 11, 40), now), '20m ago');
    expect(formatPostDate(DateTime(2026, 5, 30), now), '05-30');

    expect(formatCommentDate(DateTime(2026, 6, 18, 12), now), '2d');
    expect(formatCommentDate(DateTime(2026, 6, 20, 8), now), '4h');
    expect(formatCommentDate(DateTime(2026, 6, 20, 11, 40), now), '20m');
    expect(formatCommentDate(DateTime(2026, 5, 30), now), '05-30');
    expect(formatCommentDate(DateTime(2025, 12, 30), now), '2025-12-30');
  });

  test('post detail supports initial comment focus and unavailable snackbar',
      () {
    final source = File(
      'lib/src/features/posts/presentation/post_detail_page.dart',
    ).readAsStringSync();

    expect(source, contains('initialCommentId'));
    expect(source, contains('_focusInitialComment'));
    expect(
        source, contains('_expandedCommentIds.add(target.parentCommentId!)'));
    expect(
      source,
      contains('This comment was deleted or is no longer available.'),
    );
    expect(source, contains('Scrollable.ensureVisible'));
  });
}
