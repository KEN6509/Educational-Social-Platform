import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/presentation/post_submission_error.dart';

void main() {
  test('explains that posting requires an internet connection', () {
    expect(
      postSubmissionErrorMessage(
        const SocketException('Failed host lookup'),
      ),
      'No internet connection. Connect to the internet before posting.',
    );
  });

  test('explains when AI moderation usage is unavailable', () {
    expect(
      postSubmissionErrorMessage(
        Exception('429 RESOURCE_EXHAUSTED: moderation quota exceeded'),
      ),
      'AI moderation usage limit has been reached. Please try again later.',
    );
  });

  test('uses a safe message for other posting failures', () {
    expect(
      postSubmissionErrorMessage(Exception('database failure')),
      'Unable to post right now. Please try again.',
    );
  });
}
