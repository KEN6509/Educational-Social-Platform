import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cyanzone_mobile/src/features/posts/data/shared_preferences_pending_moderation_retry_store.dart';
import 'package:cyanzone_mobile/src/features/posts/domain/pending_moderation_retry.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores each target once and removes only the requested target',
      () async {
    final store = SharedPreferencesPendingModerationRetryStore(
      currentUserId: () => 'member-1',
    );
    const post = PendingModerationTarget.post('post-1');
    const comment = PendingModerationTarget.comment('comment-1');

    await store.save(post);
    await store.save(post);
    await store.save(comment);

    expect(await store.load(), [post, comment]);

    await store.remove(post);
    expect(await store.load(), [comment]);
  });

  test('keeps pending targets isolated between signed-in users', () async {
    var currentUserId = 'member-1';
    final store = SharedPreferencesPendingModerationRetryStore(
      currentUserId: () => currentUserId,
    );

    await store.save(const PendingModerationTarget.post('post-1'));
    currentUserId = 'member-2';

    expect(await store.load(), isEmpty);
  });
}
