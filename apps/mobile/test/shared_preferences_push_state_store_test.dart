import 'package:cyanzone_mobile/src/features/notifications/data/shared_preferences_push_state_store.dart';
import 'package:cyanzone_mobile/src/features/notifications/domain/push_destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps a stable installation id and one pending destination', () async {
    final store = SharedPreferencesPushStateStore();
    final first = await store.installationId();
    final second = await store.installationId();
    expect(first, second);

    const destination = PushDestination(
      sourceTable: 'notifications',
      sourceId: 'source-1',
      route: PushRoute.post,
      postId: 'post-1',
    );
    await store.savePendingDestination(destination);
    expect((await store.readPendingDestination())?.postId, 'post-1');
    await store.clearPendingDestination();
    expect(await store.readPendingDestination(), isNull);
  });
}
