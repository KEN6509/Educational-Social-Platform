import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:cyanzone_mobile/src/features/chat/data/chat_repository.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_details_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_room_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_widgets.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/create_group_chat_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/notification_sections_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('UnreadBadge hides zero and shows capped count', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 0)));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 120)));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('ChatMessageBubble aligns current user messages to the right',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(body: 'Hello', isMine: true),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    final align = tester.widget<Align>(find.byType(Align).first);
    expect(align.alignment, Alignment.centerRight);
  });

  testWidgets('ChatMessageBubble highlights selected message row',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            body: 'Selected',
            isMine: true,
            isSelected: true,
          ),
        ),
      ),
    );

    final highlight = tester.widget<AnimatedContainer>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.key.toString().contains('chat-message-selected-row-'),
          )
          .first,
    );
    expect(highlight.decoration, isA<BoxDecoration>());
    expect((highlight.decoration! as BoxDecoration).color, isNotNull);
  });

  testWidgets('group image sender name aligns with text sender name',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatMessageBubble(
                body: 'Hello from text',
                isMine: false,
                senderName: 'Text Sender',
                showSenderName: true,
              ),
              ChatMessageBubble(
                body: '${ChatMessage.imagePrefix}https://example.com/photo.jpg',
                isMine: false,
                senderName: 'Image Sender',
                showSenderName: true,
              ),
            ],
          ),
        ),
      ),
    );

    final textSenderLeft = tester.getTopLeft(find.text('Text Sender')).dx;
    final imageSenderLeft = tester.getTopLeft(find.text('Image Sender')).dx;
    expect(imageSenderLeft, closeTo(textSenderLeft, 0.1));
  });

  testWidgets('ChatMessageBubble opens image preview on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            body: '${ChatMessage.imagePrefix}https://example.com/photo.jpg',
            isMine: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, const Color(0xFFF1F3F5));
    final downloadButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.download_rounded),
    );
    expect(downloadButton.onPressed, isNotNull);
  });

  test('chat preview downloads real images and keeps thumbnail errors quiet',
      () {
    final source = File('lib/src/features/chat/presentation/chat_widgets.dart')
        .readAsStringSync();
    final roomSource =
        File('lib/src/features/chat/presentation/chat_room_page.dart')
            .readAsStringSync();

    expect(source, contains('const chatInput = Colors.white'));
    expect(source, contains('const chatPreviewBackground = Color(0xFFF1F3F5)'));
    expect(source, contains('backgroundColor: Colors.white'));
    expect(source, contains('PhotoManager.editor.saveImage'));
    expect(source, contains('_ChatImageThumbnailLoadError'));
    expect(source, contains('_ChatImageLoadError'));
    expect(source, contains('foregroundColor: chatNavy'));
    expect(source, isNot(contains('Image link copied')));
    expect(source, isNot(contains('Clipboard.setData')));
    expect(roomSource, contains('fillColor: chatInput'));
  });

  test('chat notification shortcuts use soft rounded-square icon tiles', () {
    final source = File('lib/src/features/chat/presentation/chat_page.dart')
        .readAsStringSync();

    expect(source, contains('Color(0xFFFFE4E6)'));
    expect(source, contains('Color(0xFFBE123C)'));
    expect(source, contains('Color(0xFFE8F7EF)'));
    expect(source, contains('Color(0xFF15803D)'));
    expect(source, contains('Color(0xFFEFF6FF)'));
    expect(source, contains('Color(0xFF1D4ED8)'));
    expect(source, contains('borderRadius: BorderRadius.circular(16)'));
    expect(source, isNot(contains('shape: BoxShape.circle')));
  });

  test('media picker camera tile matches Done action color', () {
    final source = File(
      'lib/src/features/media/presentation/device_photo_picker_page.dart',
    ).readAsStringSync();

    expect(source, contains('Color(0xFFF1F5F9)'));
    expect(
      source,
      contains('Icons.photo_camera_rounded, color: Color(0xFF0B1F3E)'),
    );
    expect(source,
        contains("color: Color(0xFF0B1F3E),\n                fontSize: 11"));
  });

  test('chat info pages wire contact and member rows to profile pages', () {
    final detailsSource =
        File('lib/src/features/chat/presentation/chat_details_page.dart')
            .readAsStringSync();
    final groupSource =
        File('lib/src/features/chat/presentation/chat_group_pages.dart')
            .readAsStringSync();

    expect(detailsSource,
        contains("import '../../profile/presentation/profile_page.dart';"));
    expect(detailsSource, contains('ProfilePage('));
    expect(detailsSource, contains('userId: _conversation.otherUserId'));
    expect(detailsSource, contains('width: double.infinity'));
    expect(groupSource,
        contains("import '../../profile/presentation/profile_page.dart';"));
    expect(groupSource, contains('void _openProfile(ChatParticipant member)'));
    expect(groupSource, contains('onTap: () => _openProfile(member)'));
  });

  testWidgets(
      'ChatMessageBubble selects image instead of previewing in select mode',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            body: '${ChatMessage.imagePrefix}https://example.com/photo.jpg',
            isMine: true,
            isSelectionMode: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('ChatMessageBubble renders four image thumbnail as square grid',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatMessageBubble(
              body:
                  '${ChatMessage.multiImagePrefix}["https://example.com/a.jpg","https://example.com/b.jpg","https://example.com/c.jpg","https://example.com/d.jpg"]',
              isMine: true,
            ),
          ),
        ),
      ),
    );

    final gridSize = tester.getSize(find.byType(GridView).first);
    expect(gridSize.width, closeTo(gridSize.height, 0.1));
  });

  testWidgets('ChatMessageBubble renders three images as tall-left collage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatMessageBubble(
              body:
                  '${ChatMessage.multiImagePrefix}[{"url":"https://example.com/a.jpg","aspectRatio":0.65},{"url":"https://example.com/b.jpg","aspectRatio":1},{"url":"https://example.com/c.jpg","aspectRatio":1}]',
              isMine: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const ValueKey('chat-image-tall-left-first')),
        findsOneWidget);
    final heroSize = tester.getSize(find.byType(Hero).first);
    expect(heroSize.height, greaterThan(heroSize.width * 0.9));
    final secondTile = tester.getSize(
      find.byKey(const ValueKey('chat-image-right-top-square')).first,
    );
    final thirdTile = tester.getSize(
      find.byKey(const ValueKey('chat-image-right-bottom-square')).first,
    );
    expect(secondTile.width, closeTo(secondTile.height, 0.1));
    expect(thirdTile.width, closeTo(thirdTile.height, 0.1));
  });

  testWidgets('ChatMessageBubble renders three images as top-wide collage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatMessageBubble(
              body:
                  '${ChatMessage.multiImagePrefix}[{"url":"https://example.com/a.jpg","aspectRatio":1.4},{"url":"https://example.com/b.jpg","aspectRatio":1},{"url":"https://example.com/c.jpg","aspectRatio":1}]',
              isMine: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const ValueKey('chat-image-top-wide-first')),
        findsOneWidget);
    final firstTile = tester.getSize(
      find.byKey(const ValueKey('chat-image-top-wide-first')).first,
    );
    expect(firstTile.width, greaterThan(firstTile.height * 1.8));
    final secondTile = tester.getSize(
      find.byKey(const ValueKey('chat-image-bottom-left-square')).first,
    );
    final thirdTile = tester.getSize(
      find.byKey(const ValueKey('chat-image-bottom-right-square')).first,
    );
    expect(secondTile.width, closeTo(secondTile.height, 0.1));
    expect(thirdTile.width, closeTo(thirdTile.height, 0.1));
  });

  testWidgets('ChatParticipantRow aligns admin badge with remove button column',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              ChatParticipantRow(
                participant: ChatParticipant(
                  id: 'admin',
                  name: 'Admin User',
                  role: 'owner',
                ),
                showAdmin: true,
              ),
              ChatParticipantRow(
                participant: ChatParticipant(
                  id: 'member',
                  name: 'Member User',
                ),
                showAdmin: true,
                trailing: SizedBox(
                  width: 40,
                  height: 32,
                  child: IconButton(
                    onPressed: null,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final adminBadge = find.ancestor(
      of: find.text('Admin'),
      matching: find.byType(Container),
    );
    final adminRight = tester.getTopRight(adminBadge.first).dx;
    final removeRight = tester.getTopRight(find.byType(IconButton)).dx;
    expect(adminRight, closeTo(removeRight, 0.1));
  });

  test('group member remove button uses compact circular sizing', () {
    final source = File(
      'lib/src/features/chat/presentation/chat_group_pages.dart',
    ).readAsStringSync();

    expect(source, contains('SizedBox.square'));
    expect(source, contains('dimension: 24'));
    expect(source, contains('CircleBorder'));
  });

  testWidgets('ChatPage renders title, search, and empty state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          loadConversations: () async => const [],
          loadRequests: () async => const [],
          loadCounts: () async => const {
            NotificationSection.activity: 0,
            NotificationSection.system: 0,
            NotificationSection.followers: 0,
            NotificationSection.chat: 0,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Search name or group'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('New Followers'), findsOneWidget);
    expect(find.text('No chats yet'), findsOneWidget);
  });

  testWidgets('ChatPage message filters include unread between all and groups',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          loadConversations: () async => const [],
          loadRequests: () async => const [],
          loadCounts: () async => const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final allX = tester.getTopLeft(find.text('All')).dx;
    final unreadX = tester.getTopLeft(find.text('Unread')).dx;
    final groupsX = tester.getTopLeft(find.text('Groups')).dx;
    final requestsX = tester.getTopLeft(find.text('Requests')).dx;

    expect(allX, lessThan(unreadX));
    expect(unreadX, lessThan(groupsX));
    expect(groupsX, lessThan(requestsX));
  });

  testWidgets('Unread filter empty state can switch back to all chats',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          loadConversations: () async => [
            ChatConversation.fromMap({
              'id': 'c1',
              'type': 'direct',
              'request_status': 'accepted',
              'unread_count': 0,
              'other_user_name': 'Alicia',
            }),
          ],
          loadRequests: () async => const [],
          loadCounts: () async => const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('No chats in Unread'), findsOneWidget);
    expect(find.text('View all chats'), findsOneWidget);

    await tester.tap(find.text('View all chats'));
    await tester.pumpAndSettle();

    expect(find.text('Alicia'), findsOneWidget);
  });

  testWidgets('ChatRoomPage keeps text when send fails', (tester) async {
    final conversation = ChatConversation.fromMap({
      'id': 'send-fail-test',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_name': 'Ming',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: conversation,
          loadMessages: () async => const [],
          sendMessage: (_, __) async => throw Exception('network'),
          markRead: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('ChatRoomPage does not show offline snackbar after send succeeds',
      (tester) async {
    final conversation = ChatConversation.fromMap({
      'id': 'send-success-test',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_name': 'Ming',
    });
    var sendCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: conversation,
          loadMessages: () async => const [],
          sendMessage: (_, __) async {
            sendCount += 1;
          },
          markRead: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sendCount, 1);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets(
      'ChatRoomPage displays oldest messages first and newest at bottom',
      (tester) async {
    final conversation = ChatConversation.fromMap({
      'id': 'order-test',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_name': 'Ming',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: conversation,
          loadMessages: () async => [
            ChatMessage.fromMap({
              'id': 'm1',
              'conversation_id': 'order-test',
              'sender_id': 'u2',
              'body': 'old message',
              'created_at': '2026-06-29T10:00:00Z',
            }, currentUserId: 'u1'),
            ChatMessage.fromMap({
              'id': 'm2',
              'conversation_id': 'order-test',
              'sender_id': 'u2',
              'body': 'latest message',
              'created_at': '2026-06-29T10:01:00Z',
            }, currentUserId: 'u1'),
          ],
          sendMessage: (_, __) async {},
          markRead: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('old message')).dy,
      lessThan(tester.getTopLeft(find.text('latest message')).dy),
    );
  });

  testWidgets('ChatRoomPage allows selecting multiple message bubbles',
      (tester) async {
    final conversation = ChatConversation.fromMap({
      'id': 'multi-select-test',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_name': 'Ming',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: conversation,
          loadMessages: () async => [
            ChatMessage.fromMap({
              'id': 'm1',
              'conversation_id': 'multi-select-test',
              'sender_id': 'u2',
              'body': 'first selectable',
              'created_at': '2026-06-29T10:00:00Z',
            }, currentUserId: 'u1'),
            ChatMessage.fromMap({
              'id': 'm2',
              'conversation_id': 'multi-select-test',
              'sender_id': 'u2',
              'body': 'second selectable',
              'created_at': '2026-06-29T10:01:00Z',
            }, currentUserId: 'u1'),
          ],
          sendMessage: (_, __) async {},
          markRead: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('first selectable'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('second selectable'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.key.toString().contains('chat-message-selected-row-'),
      ),
      findsNWidgets(2),
    );

    await tester.tap(find.text('first selectable'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('ChatRoomPage hides copy when text and image are both selected',
      (tester) async {
    final conversation = ChatConversation.fromMap({
      'id': 'mixed-select-test',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_name': 'Ming',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: conversation,
          loadMessages: () async => [
            ChatMessage.fromMap({
              'id': 'm1',
              'conversation_id': 'mixed-select-test',
              'sender_id': 'u2',
              'body': 'copyable text',
              'created_at': '2026-06-29T10:00:00Z',
            }, currentUserId: 'u1'),
            ChatMessage.fromMap({
              'id': 'm2',
              'conversation_id': 'mixed-select-test',
              'sender_id': 'u2',
              'body': '${ChatMessage.imagePrefix}https://example.com/a.jpg',
              'created_at': '2026-06-29T10:01:00Z',
            }, currentUserId: 'u1'),
          ],
          sendMessage: (_, __) async {},
          markRead: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('copyable text'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
  });

  testWidgets('CreateGroupChatPage enables create after selecting a person',
      (tester) async {
    String? createdTitle;
    List<String>? createdMembers;

    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupChatPage(
          loadSuggested: () async => const [
            ChatParticipant(id: 'u2', name: 'Ming'),
          ],
          createGroup: (title, memberIds) async {
            createdTitle = title;
            createdMembers = memberIds;
            return 'c1';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Ming'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();

    expect(createdTitle, 'Group chat');
    expect(createdMembers, ['u2']);
  });

  testWidgets('NotificationSectionsPage shows selected section title',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.system,
          loadNotifications: (_) async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Notifications'), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
    expect(
      find.text('New updates will appear here when something happens.'),
      findsOneWidget,
    );
  });

  testWidgets('New Followers rows open follower profile and show latest label',
      (tester) async {
    ChatNotification? openedNotification;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.followers,
          openFollowerProfile: (notification) {
            openedNotification = notification;
          },
          loadNotifications: (_) async => [
            ChatNotification.fromMap({
              'id': 'follower-1',
              'type': 'new_follower',
              'actor_id': 'user-follower-1',
              'title': 'New follower',
              'body': 'Someone started following you',
              'created_at': '2026-07-05T08:30:00',
              'profiles': {
                'name': 'Alicia',
              },
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Followers'), findsOneWidget);
    expect(find.text('Alicia'), findsOneWidget);
    expect(find.textContaining('Started following you'), findsOneWidget);

    await tester.tap(find.text('Alicia'));
    await tester.pumpAndSettle();

    expect(openedNotification?.actorId, 'user-follower-1');
  });

  testWidgets('Activity page shows filter dropdown and rich activity row',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.activity,
          loadNotifications: (_) async => [
            ChatNotification.fromMap({
              'id': 'activity-1',
              'type': 'mention',
              'actor_id': 'actor-1',
              'post_id': 'post-1',
              'title': 'Mention',
              'body': 'Someone mentioned you',
              'created_at': '2026-07-05T08:30:00',
              'profiles': {
                'name': 'Kenny',
              },
              'posts': {
                'author_id': 'post-author-1',
                'profiles': <String, dynamic>{},
                'post_images': <Map<String, dynamic>>[],
              },
            }),
            ChatNotification.fromMap({
              'id': 'activity-2',
              'type': 'like',
              'actor_id': 'actor-2',
              'post_id': 'post-2',
              'title': 'Like',
              'body': 'Someone liked your post',
              'created_at': '2026-07-05T08:00:00',
              'profiles': {'name': 'Ming'},
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Kenny'), findsOneWidget);
    expect(find.text('mentioned you'), findsOneWidget);
    expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Likes & Favorites'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Mentions'), findsOneWidget);

    await tester.tap(find.text('Mentions'));
    await tester.pumpAndSettle();

    expect(find.text('Kenny'), findsOneWidget);
    expect(find.text('Ming'), findsNothing);
  });

  testWidgets('NotificationSectionsPage marks section read when leaving',
      (tester) async {
    NotificationSection? markedSection;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.activity,
          loadNotifications: (_) async => const [],
          markSectionRead: (section) async {
            markedSection = section;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(markedSection, NotificationSection.activity);
  });

  testWidgets('Activity row shows missing post snackbar when post cannot open',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.activity,
          loadNotifications: (_) async => [
            ChatNotification.fromMap({
              'id': 'activity-missing',
              'type': 'comment',
              'actor_id': 'actor-1',
              'post_id': 'post-missing',
              'title': 'Comment',
              'body': 'Comment',
              'created_at': '2026-07-06T09:00:00',
              'profiles': {'name': 'Chan'},
            }),
          ],
          openActivityPost: (_) async {
            throw const ChatNotificationPostUnavailableException();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chan'));
    await tester.pump();

    expect(
      find.text(
        "This post can't be viewed. It may be deleted or not approved yet.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('ChatDetailsPage exposes group edit and clear chat',
      (tester) async {
    final group = ChatConversation.fromMap({
      'id': 'c1',
      'type': 'group',
      'request_status': 'none',
      'unread_count': 0,
      'title': 'Trip group',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailsPage(
          conversation: group,
          clearChat: (_) async {},
          renameGroup: (_, __) async {},
        ),
      ),
    );

    expect(find.text('Group Info'), findsOneWidget);
    expect(find.text('Trip group'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.text('Clear chat'), findsOneWidget);
  });
}
