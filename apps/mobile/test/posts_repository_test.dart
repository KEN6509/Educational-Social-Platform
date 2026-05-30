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
}
