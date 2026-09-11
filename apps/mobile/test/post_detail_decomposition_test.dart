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
}
