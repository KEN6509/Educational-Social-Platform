import 'package:cyanzone_mobile/src/features/posts/presentation/create_post_validation.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create post attachment grid crops thumbnails to square cover', () {
    final source = File(
      'lib/src/features/posts/presentation/create_post_page.dart',
    ).readAsStringSync();
    final gridStart = source.indexOf('class _ModernImageGrid');
    expect(gridStart, greaterThanOrEqualTo(0));
    final gridSource = source.substring(gridStart);

    expect(gridSource, contains('childAspectRatio: 1'));
    expect(gridSource, contains('fit: BoxFit.cover'));
    expect(gridSource, isNot(contains('fit: BoxFit.contain')));
  });

  test('requires either content or an image', () {
    expect(canSubmitPostBody(content: '', imageCount: 0), isFalse);
    expect(canSubmitPostBody(content: 'A note', imageCount: 0), isTrue);
    expect(canSubmitPostBody(content: '   ', imageCount: 1), isTrue);
  });
}
