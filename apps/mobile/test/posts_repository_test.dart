import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/data/posts_repository.dart';

void main() {
  test('feed query embeds the post author profile explicitly', () {
    expect(
      PostsRepository.feedSelectColumns,
      contains('profiles!posts_author_id_fkey'),
    );
    expect(
      PostsRepository.feedSelectColumns,
      isNot(contains('profiles(name')),
    );
  });

  test('feed query includes dislike hidden window for discovery filtering', () {
    expect(PostsRepository.feedSelectColumns, contains('hidden_until'));
  });

  test('report reasons are stable labels for the mobile report page', () {
    expect(
      PostsRepository.reportReasons,
      contains('Bullying or harassment'),
    );
    expect(PostsRepository.reportReasons, contains('False information'));
    expect(PostsRepository.reportReasons.length, greaterThanOrEqualTo(7));
  });

  test('report payload contains only the current reason-based contract', () {
    final payload = PostsRepository.buildReportPayload(
      reporterId: 'member-1',
      targetType: 'post',
      targetId: 'post-1',
      reason: 'Spam',
    );

    expect(payload, {
      'reporter_id': 'member-1',
      'target_type': 'post',
      'target_id': 'post-1',
      'reason': 'Spam',
    });
    expect(payload, isNot(contains('description')));
  });

  test('saved and liked profile queries embed posts through inner joins', () {
    expect(
      PostsRepository.savedPostsSelectColumns,
      contains('posts!inner'),
    );
    expect(
      PostsRepository.likedPostsSelectColumns,
      contains('posts!inner'),
    );
  });

  test('post images use the shared images storage bucket', () {
    final source = File('lib/src/features/posts/data/posts_repository.dart')
        .readAsStringSync();

    expect(source, contains(".storage.from('images')"));
    expect(source, isNot(contains(".storage.from('post-images')")));
  });

  test('submission writes return IDs and leave moderation authority to SQL',
      () {
    final source = File('lib/src/features/posts/data/posts_repository.dart')
        .readAsStringSync();
    final postStart = source.indexOf('Future<String> createPost');
    final commentStart = source.indexOf('Future<String> createComment');
    expect(postStart, greaterThanOrEqualTo(0));
    expect(commentStart, greaterThanOrEqualTo(0));
    expect(
        source.substring(commentStart, postStart), contains(".select('id')"));
    expect(source.substring(commentStart, postStart), contains('.single()'));
    expect(source, contains("'mime_type': image.contentType"));
    expect(source, isNot(contains("'moderation_status': 'pending'")));
    expect(source, isNot(contains("'reviewed_by': null")));
  });

  test('removePost deletes post image rows and storage objects', () {
    final source = File('lib/src/features/posts/data/posts_repository.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> removePost');
    final end = source.indexOf('Future<List<PostComment>> fetchComments');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final removePostSource = source.substring(start, end);
    expect(removePostSource, contains(".from('post_images')"));
    expect(removePostSource, contains('.delete()'));
    expect(removePostSource, contains(".storage.from('images').remove"));
  });
}
