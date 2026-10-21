Future<void> replaceProfileAvatar({
  required String newPath,
  required String? oldPath,
  required Future<void> Function() uploadNew,
  required Future<void> Function() saveProfile,
  required Future<bool> Function() isNewAvatarReferenced,
  required Future<void> Function(String path) remove,
  void Function(String path, Object error, StackTrace stack)? onCleanupError,
}) async {
  await uploadNew();
  Future<void> tryRemove(String path) async {
    try {
      await remove(path);
    } catch (error, stack) {
      onCleanupError?.call(path, error, stack);
    }
  }

  try {
    await saveProfile();
  } catch (_) {
    bool? isReferenced;
    try {
      isReferenced = await isNewAvatarReferenced();
    } catch (error, stack) {
      onCleanupError?.call(newPath, error, stack);
    }
    if (isReferenced != true) {
      if (isReferenced == false) {
        await tryRemove(newPath);
      }
      rethrow;
    }
  }

  if (oldPath != null && oldPath != newPath) {
    await tryRemove(oldPath);
  }
}
