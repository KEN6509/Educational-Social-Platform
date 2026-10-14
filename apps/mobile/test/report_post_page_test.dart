import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cyanzone_mobile/src/features/posts/presentation/report_post_page.dart';

void main() {
  test('duplicate unresolved report gets a specific message', () {
    const error = PostgrestException(
      message:
          'duplicate key value violates unique constraint "reports_one_unresolved_per_reporter_target"',
      code: '23505',
    );

    expect(
      reportSubmissionErrorMessage(error),
      'You have already reported this content.',
    );
  });

  test('other unique constraint errors keep the general message', () {
    const error = PostgrestException(
      message: 'duplicate key value violates unique constraint "other_index"',
      code: '23505',
    );

    expect(
      reportSubmissionErrorMessage(error),
      'Unable to submit this report. Please try again.',
    );
  });

  test('other submission failures keep the general message', () {
    expect(
      reportSubmissionErrorMessage(Exception('offline')),
      'Unable to submit this report. Please try again.',
    );
  });
}
