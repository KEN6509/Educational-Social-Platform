import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const presentationPath = 'lib/src/features/posts/presentation';

  test('post detail media lives in its feature-local part', () {
    final page =
        File('$presentationPath/post_detail_page.dart').readAsStringSync();
    final mediaFile = File('$presentationPath/post_detail_media.dart');

    expect(page, contains("part 'post_detail_media.dart';"));
    expect(mediaFile.existsSync(), isTrue);
    if (!mediaFile.existsSync()) return;

    final media = mediaFile.readAsStringSync();
    expect(media, startsWith("part of 'post_detail_page.dart';"));
    expect(media, contains('class _PostDetailNetworkImage'));
    expect(media, contains('class _PostDetailImagePreviewPage'));
    expect(media, contains('class _PostDetailZoomablePreviewImage'));
    expect(media, contains('class _PostDetailPreviewHeader'));
    expect(media, contains('class _PostDetailImageLoadError'));
    expect(page, isNot(contains('class _PostDetailImagePreviewPage')));
  });

  test('post share sheet lives in its feature-local part', () {
    final page =
        File('$presentationPath/post_detail_page.dart').readAsStringSync();
    final shareFile = File('$presentationPath/post_share_sheet.dart');

    expect(page, contains("part 'post_share_sheet.dart';"));
    expect(shareFile.existsSync(), isTrue);
    if (!shareFile.existsSync()) return;

    final share = shareFile.readAsStringSync();
    expect(share, startsWith("part of 'post_detail_page.dart';"));
    expect(share, contains('class _ShareSheet'));
    expect(share, contains('class _ShareContactAvatar'));
    expect(share, contains('class _ActionGridItem'));
    expect(page, isNot(contains('class _ShareSheet')));
  });

  test('post detail comment widgets live in their feature-local part', () {
    final page =
        File('$presentationPath/post_detail_page.dart').readAsStringSync();
    final commentsFile = File('$presentationPath/post_detail_comments.dart');

    expect(page, contains("part 'post_detail_comments.dart';"));
    expect(commentsFile.existsSync(), isTrue);
    if (!commentsFile.existsSync()) return;

    final comments = commentsFile.readAsStringSync();
    expect(comments, startsWith("part of 'post_detail_page.dart';"));
    expect(comments, contains('class _CommentsLoadError'));
    expect(comments, contains('class _CommentInputModal'));
    expect(comments, contains('class _CommentItem'));
    expect(comments, contains('class _CommentLikeButton'));
    expect(page, isNot(contains('class _CommentItem')));
  });

  test('post detail visual actions live in their feature-local part', () {
    final page =
        File('$presentationPath/post_detail_page.dart').readAsStringSync();
    final actionsFile = File('$presentationPath/post_detail_actions.dart');

    expect(page, contains("part 'post_detail_actions.dart';"));
    expect(actionsFile.existsSync(), isTrue);
    if (!actionsFile.existsSync()) return;

    final actions = actionsFile.readAsStringSync();
    expect(actions, startsWith("part of 'post_detail_page.dart';"));
    expect(actions, contains('class _ActionButton'));
    expect(actions, contains('class _FollowButton'));
    expect(page, isNot(contains('class _ActionButton')));
  });
}
