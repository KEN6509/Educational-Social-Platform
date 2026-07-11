import 'dart:io';
import 'dart:typed_data';

import 'package:cyanzone_mobile/src/features/posts/data/post_image_disk_cache.dart';
import 'package:cyanzone_mobile/src/features/profile/data/profile_avatar_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post image cache exposes warmed files synchronously', () {
    final file = File('warm-image.img');
    PostImageDiskCache.remember('https://example.com/image.jpg', file);

    expect(
      PostImageDiskCache.peek('https://example.com/image.jpg'),
      same(file),
    );
  });

  test('profile avatar cache exposes warmed bytes synchronously', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    ProfileAvatarCache.remember('user-1', bytes);

    expect(ProfileAvatarCache.peek('user-1'), same(bytes));
  });
}
