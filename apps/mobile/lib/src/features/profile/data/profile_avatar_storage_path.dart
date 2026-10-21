String profileAvatarStoragePath(String userId, {required String uploadId}) {
  return '$userId/avatar-$uploadId.jpg';
}

String? ownedProfileAvatarStoragePath({
  required String? avatarUrl,
  required String userId,
  required String expectedLegacyUrl,
}) {
  if (avatarUrl == null) return null;
  final candidate = Uri.tryParse(avatarUrl);
  final reference = Uri.tryParse(expectedLegacyUrl);
  if (candidate == null || reference == null) return null;
  if ((candidate.scheme != 'http' && candidate.scheme != 'https') ||
      candidate.origin != reference.origin) {
    return null;
  }

  final candidateSegments = candidate.pathSegments;
  final referenceSegments = reference.pathSegments;
  if (referenceSegments.length < 2 ||
      referenceSegments[referenceSegments.length - 2] != userId ||
      referenceSegments.last != 'avatar.jpg' ||
      candidateSegments.length != referenceSegments.length) {
    return null;
  }
  for (var i = 0; i < referenceSegments.length - 1; i++) {
    if (candidateSegments[i] != referenceSegments[i]) return null;
  }

  final fileName = candidateSegments.last;
  if (!RegExp(r'^avatar(?:-[A-Za-z0-9_-]+)?\.jpg$').hasMatch(fileName)) {
    return null;
  }
  return '$userId/$fileName';
}
