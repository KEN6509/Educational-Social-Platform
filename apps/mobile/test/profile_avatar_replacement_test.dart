import 'package:cyanzone_mobile/src/features/profile/data/profile_avatar_replacement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes the previous avatar only after the new profile is saved',
      () async {
    final operations = <String>[];

    await replaceProfileAvatar(
      newPath: 'user-1/avatar-new.jpg',
      oldPath: 'user-1/avatar.jpg',
      uploadNew: () async => operations.add('upload new'),
      saveProfile: () async => operations.add('save profile'),
      isNewAvatarReferenced: () async => false,
      remove: (path) async => operations.add('remove $path'),
    );

    expect(operations, [
      'upload new',
      'save profile',
      'remove user-1/avatar.jpg',
    ]);
  });

  test('removes the new upload and preserves the old avatar on save failure',
      () async {
    final operations = <String>[];

    await expectLater(
      replaceProfileAvatar(
        newPath: 'user-1/avatar-new.jpg',
        oldPath: 'user-1/avatar.jpg',
        uploadNew: () async => operations.add('upload new'),
        saveProfile: () async {
          operations.add('save profile');
          throw StateError('save failed');
        },
        isNewAvatarReferenced: () async => false,
        remove: (path) async => operations.add('remove $path'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(operations, [
      'upload new',
      'save profile',
      'remove user-1/avatar-new.jpg',
    ]);
  });

  test('does not fail the saved profile when old avatar removal fails',
      () async {
    final cleanupErrors = <String>[];

    await replaceProfileAvatar(
      newPath: 'user-1/avatar-new.jpg',
      oldPath: 'user-1/avatar.jpg',
      uploadNew: () async {},
      saveProfile: () async {},
      isNewAvatarReferenced: () async => false,
      remove: (path) async => throw StateError('remove failed'),
      onCleanupError: (path, error, _) => cleanupErrors.add('$path: $error'),
    );

    expect(cleanupErrors, ['user-1/avatar.jpg: Bad state: remove failed']);
  });

  test('does not remove any old avatar when none belongs to the user',
      () async {
    final removedPaths = <String>[];

    await replaceProfileAvatar(
      newPath: 'user-1/avatar-new.jpg',
      oldPath: null,
      uploadNew: () async {},
      saveProfile: () async {},
      isNewAvatarReferenced: () async => false,
      remove: (path) async => removedPaths.add(path),
    );

    expect(removedPaths, isEmpty);
  });

  test(
      'finishes the replacement if the database saved it despite a lost response',
      () async {
    final removedPaths = <String>[];

    await replaceProfileAvatar(
      newPath: 'user-1/avatar-new.jpg',
      oldPath: 'user-1/avatar.jpg',
      uploadNew: () async {},
      saveProfile: () async => throw StateError('response lost'),
      isNewAvatarReferenced: () async => true,
      remove: (path) async => removedPaths.add(path),
    );

    expect(removedPaths, ['user-1/avatar.jpg']);
  });

  test('keeps the new file when database verification is unavailable',
      () async {
    final removedPaths = <String>[];

    await expectLater(
      replaceProfileAvatar(
        newPath: 'user-1/avatar-new.jpg',
        oldPath: 'user-1/avatar.jpg',
        uploadNew: () async {},
        saveProfile: () async => throw StateError('response lost'),
        isNewAvatarReferenced: () async => throw StateError('offline'),
        remove: (path) async => removedPaths.add(path),
      ),
      throwsStateError,
    );

    expect(removedPaths, isEmpty);
  });
}
