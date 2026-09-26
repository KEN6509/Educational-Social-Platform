import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejection message shows the AI risk score and reason', () {
    expect(
      moderationRejectionMessage(
        subject: 'Post was not published',
        riskScore: 75,
        reason: 'Targeted harassment was detected.',
      ),
      'Post was not published. AI risk score: 75%. '
      'Reason: Targeted harassment was detected.',
    );
  });

  test('rejection message remains useful when optional details are absent', () {
    expect(
      moderationRejectionMessage(
        subject: 'Comment was not posted',
        riskScore: null,
        reason: null,
      ),
      'Comment was not posted.',
    );
  });
}
