import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:cyanzone_mobile/src/features/profile/data/user_profile.dart';
import 'package:cyanzone_mobile/src/features/profile/presentation/profile_message_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testProfile = UserProfile(
    id: 'other-user',
    email: 'other@example.com',
    name: 'Other User',
    avatarUrl: 'https://example.com/avatar.png',
  );

  testWidgets('profile Message requires a follow relationship', (tester) async {
    var navigated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openProfileMessage(
                context: context,
                profile: testProfile,
                openConversation: (_) async =>
                    throw Exception('Follow relationship required'),
                navigate: (_, __) async {
                  navigated = true;
                },
              ),
              child: const Text('Message'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Message'));
    await tester.pump();

    expect(
      find.text('Follow this user before sending a message.'),
      findsOneWidget,
    );
    expect(navigated, isFalse);
  });

  testWidgets('profile Message opens an accepted direct conversation',
      (tester) async {
    ChatConversation? openedConversation;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openProfileMessage(
                context: context,
                profile: testProfile,
                openConversation: (_) async => 'conversation-1',
                navigate: (_, conversation) async {
                  openedConversation = conversation;
                },
              ),
              child: const Text('Message'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Message'));
    await tester.pump();

    expect(openedConversation?.id, 'conversation-1');
    expect(openedConversation?.type, ChatConversationType.direct);
    expect(openedConversation?.requestStatus, ChatRequestStatus.accepted);
    expect(openedConversation?.otherUserId, testProfile.id);
    expect(openedConversation?.otherUserName, testProfile.name);
    expect(openedConversation?.otherUserAvatarUrl, testProfile.avatarUrl);
  });
}
