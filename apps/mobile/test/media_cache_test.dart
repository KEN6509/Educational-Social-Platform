import 'dart:io';
import 'dart:typed_data';

import 'package:cyanzone_mobile/src/features/posts/data/post_image_disk_cache.dart';
import 'package:cyanzone_mobile/src/features/profile/data/profile_avatar_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('profile avatar cache fetches replacement when the URL changes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(
        request.uri.path.endsWith('avatar-old.jpg') ? [1, 2, 3] : [4, 5, 6],
      );
      await request.response.close();
    });

    try {
      final baseUrl = 'http://127.0.0.1:${server.port}';
      final oldBytes = await ProfileAvatarCache.cacheFromUrl(
        userId: 'avatar-replacement',
        url: '$baseUrl/avatar-old.jpg',
      );
      final replacementBytes = await ProfileAvatarCache.cacheFromUrl(
        userId: 'avatar-replacement',
        url: '$baseUrl/avatar-new.jpg',
      );

      expect(oldBytes, [1, 2, 3]);
      expect(replacementBytes, [4, 5, 6]);
      expect(ProfileAvatarCache.peek('avatar-replacement'), [4, 5, 6]);
    } finally {
      await server.close(force: true);
    }
  });
}
