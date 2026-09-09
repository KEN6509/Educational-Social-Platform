import 'package:cyanzone_mobile/src/features/notifications/domain/push_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and serializes a versioned push destination', () {
    const destination = PushDestination(
      sourceTable: 'notifications',
      sourceId: 'notification-1',
      route: PushRoute.conversation,
      conversationId: 'conversation-1',
    );

    final parsed = PushDestination.tryParse(destination.toData());
    expect(parsed?.route, PushRoute.conversation);
    expect(parsed?.conversationId, 'conversation-1');
  });

  test('rejects unknown versions and routes', () {
    expect(
      PushDestination.tryParse({
        'version': '2',
        'sourceTable': 'notifications',
        'sourceId': 'source-1',
        'route': 'post',
      }),
      isNull,
    );
    expect(
      PushDestination.tryParse({
        'version': '1',
        'sourceTable': 'notifications',
        'sourceId': 'source-1',
        'route': 'unknown',
      }),
      isNull,
    );
  });
}
