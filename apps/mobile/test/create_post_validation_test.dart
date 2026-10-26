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
    expect(gridSource, contains('padding: EdgeInsets.zero'));
    expect(gridSource, contains('final ValueChanged<int> onPreview;'));
    expect(gridSource, contains('onTap: () => onPreview(index)'));
    expect(gridSource, contains('onTap: () => onRemove(index)'));
    expect(source, contains('DraftImagePreviewPage('));
    expect(source, contains('MemoryImage(image.bytes!)'));
    expect(source, contains('NetworkImage(image.url!)'));
    expect(
      source,
      contains('withNavigationClearance('),
    );
    expect(source, contains('additionalBottom: AppSpacing.lg'));
    expect(source, contains('const SizedBox(height: AppSpacing.section)'));
  });

  test('requires either content or an image', () {
    expect(canSubmitPostBody(content: '', imageCount: 0), isFalse);
    expect(canSubmitPostBody(content: 'A note', imageCount: 0), isTrue);
    expect(canSubmitPostBody(content: '   ', imageCount: 1), isTrue);
  });

  test('post image size accepts the 10 MiB boundary and rejects one byte over',
      () {
    expect(maxPostImageBytes, 10485760);
    expect(postImageExceedsLimit(maxPostImageBytes - 1), isFalse);
    expect(postImageExceedsLimit(maxPostImageBytes), isFalse);
    expect(postImageExceedsLimit(maxPostImageBytes + 1), isTrue);
  });

  test('oversized images are checked before creating a post', () {
    final source = File(
      'lib/src/features/posts/presentation/create_post_page.dart',
    ).readAsStringSync();
    final submit = source.substring(
      source.indexOf('Future<void> _submit()'),
      source.indexOf('Future<void> _moderatePost('),
    );
    final sizeCheck = submit.indexOf('postImageExceedsLimit(');
    final create = submit.indexOf('_repository.createPost(');
    final update = submit.indexOf('_repository.updatePost(');

    expect(sizeCheck, greaterThanOrEqualTo(0));
    expect(sizeCheck, lessThan(create));
    expect(sizeCheck, lessThan(update));
  });

  test('oversized images are rejected during selection', () {
    final source = File(
      'lib/src/features/posts/presentation/create_post_page.dart',
    ).readAsStringSync();
    final picker = source.substring(
      source.indexOf('Future<void> _pickImages()'),
      source.indexOf('void _removeImage('),
    );

    expect(picker, contains('postImageExceedsLimit('));
    expect(picker, contains('postImageSizeErrorMessage'));
  });
}
