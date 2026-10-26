bool canSubmitPostBody({
  required String content,
  required int imageCount,
}) {
  return content.trim().isNotEmpty || imageCount > 0;
}

const maxPostImageBytes = 10 * 1024 * 1024;
const postImageSizeErrorMessage = 'Each image must be 10 MB or smaller.';

bool postImageExceedsLimit(int byteCount) => byteCount > maxPostImageBytes;
