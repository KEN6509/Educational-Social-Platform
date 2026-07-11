import 'dart:io';

import '../../../core/errors/friendly_error.dart';

Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('example.com')
        .timeout(const Duration(seconds: 2));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

String postSubmissionErrorMessage(Object error) {
  if (friendlyErrorTitle(error) == 'No internet connection') {
    return 'No internet connection. Connect to the internet before posting.';
  }

  final message = error.toString().toLowerCase();
  final isModerationUsageError = message.contains('429') ||
      message.contains('resource_exhausted') ||
      message.contains('quota') ||
      message.contains('usage limit') ||
      message.contains('rate limit') ||
      message.contains('insufficient credit');
  if (isModerationUsageError) {
    return 'AI moderation usage limit has been reached. Please try again later.';
  }

  return 'Unable to post right now. Please try again.';
}
