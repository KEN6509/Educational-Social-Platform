import 'package:cyanzone_mobile/src/features/profile/data/profile_avatar_storage_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each avatar replacement uses a new storage path', () {
    final first = profileAvatarStoragePath('user-1', uploadId: 'upload-1');
    final replacement =
        profileAvatarStoragePath('user-1', uploadId: 'upload-2');

    expect(first, 'user-1/avatar-upload-1.jpg');
    expect(replacement, 'user-1/avatar-upload-2.jpg');
    expect(replacement, isNot(first));
  });
}
