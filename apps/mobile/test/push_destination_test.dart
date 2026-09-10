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

  test('round trips every supported route name', () {
    const destinations = [
      PushDestination(
          sourceTable: 'notifications',
          sourceId: '1',
          route: PushRoute.conversation,
          conversationId: 'c'),
      PushDestination(
          sourceTable: 'notifications',
          sourceId: '2',
          route: PushRoute.post,
          postId: 'p'),
      PushDestination(
          sourceTable: 'notifications',
          sourceId: '3',
          route: PushRoute.profile,
          profileId: 'u'),
      PushDestination(
          sourceTable: 'notifications',
          sourceId: '4',
          route: PushRoute.systemNotification,
          notificationId: '4'),
      PushDestination(
          sourceTable: 'supervision_notifications',
          sourceId: '5',
          route: PushRoute.familyLink,
          linkId: 'l'),
      PushDestination(
          sourceTable: 'supervision_notifications',
          sourceId: '6',
          route: PushRoute.checkIn,
          checkInId: 'ci'),
      PushDestination(
          sourceTable: 'supervision_notifications',
          sourceId: '7',
          route: PushRoute.sos,
          sosId: 's'),
      PushDestination(
          sourceTable: 'supervision_notifications',
          sourceId: '8',
          route: PushRoute.screenTime,
          childId: 'child'),
    ];

    for (final destination in destinations) {
      expect(PushDestination.tryParse(destination.toData())?.route,
          destination.route);
    }
  });

  test('rejects unknown sources and routes missing their required id', () {
    expect(
      PushDestination.tryParse({
        'version': '1',
        'sourceTable': 'profiles',
        'sourceId': 'source-1',
        'route': 'profile',
        'profileId': 'profile-1',
      }),
      isNull,
    );
    expect(
      PushDestination.tryParse({
        'version': '1',
        'sourceTable': 'notifications',
        'sourceId': 'source-1',
        'route': 'conversation',
      }),
      isNull,
    );
  });
}
