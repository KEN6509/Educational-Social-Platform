bool canSubmitPostBody({
  required String content,
  required int imageCount,
}) {
  return content.trim().isNotEmpty || imageCount > 0;
}
