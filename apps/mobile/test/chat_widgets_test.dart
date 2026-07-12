import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:cyanzone_mobile/src/features/chat/data/chat_mention.dart';
import 'package:cyanzone_mobile/src/features/chat/data/chat_repository.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_details_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_room_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_widgets.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/create_group_chat_page.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/notification_sections_page.dart';

void main() {
  testWidgets('ChatMessageBubble renders tappable structured mentions',
      (tester) async {
    String? openedId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          body: 'Hi @Ava and @Ava',
          isMine: false,
          mentions: const [
            ChatMention(
              userId: 'u1',
              displayText: '@Ava',
              start: 3,
              end: 7,
            ),
            ChatMention(
              userId: 'u1',
              displayText: '@Ava',
              start: 12,
              end: 16,
            ),
          ],
          onMentionTap: (id) => openedId = id,
        ),
      ),
    ));

    expect(find.text('@Ava'), findsNWidgets(2));
    final mentionText = tester.widget<Text>(find.text('@Ava').first);
    expect(mentionText.style?.color, const Color(0xFF128C7E));
    await tester.tap(find.byKey(const ValueKey('chat-mention-u1-3')));
    expect(openedId, 'u1');
  });

  testWidgets('conversation row shows chat mention indicator', (tester) async {
    const conversation = ChatConversation(
      id: 'group-mention',
      type: ChatConversationType.group,
      requestStatus: ChatRequestStatus.none,
      unreadCount: 0,
      title: 'Study Group',
      hasUnvisitedMention: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConversationTile(conversation: conversation, onTap: () {}),
      ),
    ));

    expect(find.byKey(const ValueKey('conversation-mention-indicator')),
        findsOneWidget);
  });

  testWidgets('group composer shows admin @all before member suggestions',
      (tester) async {
    const conversation = ChatConversation(
      id: 'group-autocomplete',
      type: ChatConversationType.group,
      requestStatus: ChatRequestStatus.none,
      unreadCount: 0,
      title: 'Study Group',
    );
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomPage(
        conversation: conversation,
        loadMessages: () async => const [],
        markRead: (_) async {},
        canMentionAll: true,
        mentionParticipants: const [
          ChatParticipant(id: 'u1', name: 'Ava'),
        ],
      ),
    ));

    await tester.enterText(find.byType(TextField), '@');
    await tester.pump();

    expect(
        find.byKey(const ValueKey('mention-all-suggestion')), findsOneWidget);
    expect(find.byKey(const ValueKey('mention-suggestion-u1')), findsOneWidget);
    final allTop = tester.getTopLeft(
      find.byKey(const ValueKey('mention-all-suggestion')),
    );
    final memberTop = tester.getTopLeft(
      find.byKey(const ValueKey('mention-suggestion-u1')),
    );
    expect(allTop.dy, lessThan(memberTop.dy));
  });

  testWidgets('mention suggestions overlay chat with four-row viewport',
      (tester) async {
    const conversation = ChatConversation(
      id: 'group-overlay',
      type: ChatConversationType.group,
      requestStatus: ChatRequestStatus.none,
      unreadCount: 0,
      title: 'Study Group',
    );
    final participants = List.generate(
      6,
      (index) => ChatParticipant(id: 'u$index', name: 'Member $index'),
    );
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomPage(
        conversation: conversation,
        loadMessages: () async => const [],
        markRead: (_) async {},
        canMentionAll: true,
        mentionParticipants: participants,
      ),
    ));
    final field = find.byType(TextField);
    final fieldTopBefore = tester.getTopLeft(field).dy;

    await tester.enterText(field, '@');
    await tester.pump();

    expect(tester.getTopLeft(field).dy, fieldTopBefore);
    final panel = find.byKey(const ValueKey('mention-suggestions-panel'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).height, lessThanOrEqualTo(240));
    expect(find.byKey(const ValueKey('mention-suggestion-divider-0')),
        findsOneWidget);
    final dividerLeft = tester
        .getTopLeft(find.byKey(const ValueKey('mention-suggestion-divider-0')))
        .dx;
    final nameLeft =
        tester.getTopLeft(find.text('Member 0', skipOffstage: false)).dx;
    expect(dividerLeft, nameLeft);
    final allAvatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byKey(const ValueKey('mention-all-suggestion')),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(allAvatar.backgroundColor, const Color(0xFF128C7E));

    await tester.drag(
      find.byKey(const ValueKey('mention-suggestions-list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Member 5'), findsOneWidget);
    await tester.tap(find.text('Member 5'));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller?.text, '@Member 5 ');

    await tester.enterText(field, 'First line\nSecond line\nThird line\n@');
    await tester.pumpAndSettle();
    final resizedPanel =
        find.byKey(const ValueKey('mention-suggestions-panel'));
    expect(
      tester.getBottomLeft(resizedPanel).dy,
      lessThanOrEqualTo(tester.getTopLeft(field).dy),
    );

    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);
    await tester.tapAt(const Offset(20, 100));
    await tester.pump();
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);
    expect(panel, findsNothing);
  });

  testWidgets('mention-only bubble shrink-wraps its text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          body: '@Ava',
          isMine: false,
          mentions: [
            ChatMention(
              userId: 'u1',
              displayText: '@Ava',
              start: 0,
              end: 4,
            ),
          ],
        ),
      ),
    ));

    final bubble = find.byKey(const ValueKey('chat-message-bubble'));
    expect(tester.getSize(bubble).width, lessThan(130));
  });

  testWidgets('mention-only timestamp shares the final text line',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          body: '@all',
          isMine: false,
          createdAt: DateTime(2026, 7, 13, 0, 37),
          mentions: const [
            ChatMention(
              userId: '',
              displayText: '@all',
              start: 0,
              end: 4,
              isAll: true,
            ),
          ],
        ),
      ),
    ));

    final mentionTop = tester.getTopLeft(find.text('@all')).dy;
    final timestampTop = tester.getTopLeft(find.text('12:37 AM')).dy;
    expect((timestampTop - mentionTop).abs(), lessThan(8));
  });

  testWidgets('mixed mention text uses normal inline layout and stays tappable',
      (tester) async {
    String? openedId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          body: 'Hello @Ava again',
          isMine: false,
          createdAt: DateTime(2026, 7, 13, 0, 38),
          mentions: const [
            ChatMention(
              userId: 'u1',
              displayText: '@Ava',
              start: 6,
              end: 10,
            ),
          ],
          onMentionTap: (id) => openedId = id,
        ),
      ),
    ));

    final messageTop = tester.getTopLeft(find.text('@Ava')).dy;
    final timestampTop = tester.getTopLeft(find.text('12:38 AM')).dy;
    expect((timestampTop - messageTop).abs(), lessThan(8));
    await tester.tap(find.byKey(const ValueKey('chat-mention-u1-6')));
    expect(openedId, 'u1');
  });

  testWidgets('scaled repeated mentions never overlap the timestamp',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(280, 600),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: ChatMessageBubble(
            body: '@Ava and @Ava',
            isMine: false,
            createdAt: DateTime(2026, 7, 13, 0, 39),
            mentions: const [
              ChatMention(
                userId: 'u1',
                displayText: '@Ava',
                start: 0,
                end: 4,
              ),
              ChatMention(
                userId: 'u1',
                displayText: '@Ava',
                start: 9,
                end: 13,
              ),
            ],
          ),
        ),
      ),
    ));

    final timestampRect = tester.getRect(find.text('12:39 AM'));
    for (final mention in find.text('@Ava').evaluate()) {
      expect(
          tester
              .getRect(find.byElementPredicate((item) => item == mention))
              .overlaps(timestampRect),
          isFalse);
    }
  });

  testWidgets('conversation mention indicator uses centered theme treatment',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConversationTile(
          conversation: const ChatConversation(
            id: 'styled-indicator',
            type: ChatConversationType.group,
            requestStatus: ChatRequestStatus.none,
            unreadCount: 0,
            hasUnvisitedMention: true,
          ),
          onTap: () {},
        ),
      ),
    ));

    final indicator =
        find.byKey(const ValueKey('conversation-mention-indicator'));
    expect(indicator, findsOneWidget);
    final decorated = tester.widget<Container>(indicator);
    final decoration = decorated.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF128C7E));
    expect(decoration.shape, BoxShape.circle);
    final glyph = tester.widget<Transform>(
      find.byKey(const ValueKey('conversation-mention-glyph')),
    );
    expect(glyph.transform.getTranslation().y, -2);
    expect(
      find.descendant(of: indicator, matching: find.text('@')),
      findsOneWidget,
    );
  });

  testWidgets('room enters oldest mention then @ button visits the next',
      (tester) async {
    final visited = <String>[];
    final messages = [
      ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'u2',
        body: 'first',
        createdAt: DateTime(2026, 7, 12, 10),
        isMine: false,
      ),
      ChatMessage(
        id: 'm2',
        conversationId: 'c1',
        senderId: 'u2',
        body: 'second',
        createdAt: DateTime(2026, 7, 12, 11),
        isMine: false,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomPage(
        conversation: const ChatConversation(
          id: 'c1',
          type: ChatConversationType.group,
          requestStatus: ChatRequestStatus.none,
          unreadCount: 2,
          title: 'Study Group',
        ),
        loadMessages: () async => messages,
        markRead: (_) async {},
        initialUnvisitedMentionMessageIds: const ['m1', 'm2'],
        markMentionVisited: (id) async => visited.add(id),
      ),
    ));
    await tester.pumpAndSettle();

    expect(visited, ['m1']);
    expect(find.byKey(const ValueKey('mention-navigation-button')),
        findsOneWidget);
    final navigationGlyph = tester.widget<Transform>(
      find.byKey(const ValueKey('mention-navigation-glyph')),
    );
    expect(navigationGlyph.transform.getTranslation().y, -2);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mention-navigation-button')),
        matching: find.text('@'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('mention-navigation-button')),
    );
    await tester.pumpAndSettle();
    expect(visited, ['m1', 'm2']);
  });

  testWidgets('room never marks a mention visited when its message is absent',
      (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomPage(
        conversation: const ChatConversation(
          id: 'c-missing',
          type: ChatConversationType.group,
          requestStatus: ChatRequestStatus.none,
          unreadCount: 0,
        ),
        loadMessages: () async => const [],
        markRead: (_) async {},
        initialUnvisitedMentionMessageIds: const ['missing-message'],
        markMentionVisited: (id) async => visited.add(id),
      ),
    ));
    await tester.pumpAndSettle();

    expect(visited, isEmpty);
  });

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

  testWidgets('ChatMessageBubble renders shared posts as compact post cards',
      (tester) async {
    final body = ChatMessage.sharedPostBody(
      postId: 'post-1',
      authorName: 'Chan',
      title: 'Weekend hiking',
      content: 'A short trail guide.',
      imageUrl: 'https://example.com/post.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            body: body,
            isMine: true,
            createdAt: DateTime(2026, 7, 8, 12, 38),
          ),
        ),
      ),
    );

    expect(find.text('Weekend hiking'), findsOneWidget);
    expect(find.text('Chan'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.textContaining(ChatMessage.sharedPostPrefix), findsNothing);
  });

  testWidgets('ChatMessageBubble opens shared post through tap callback',
      (tester) async {
    final body = ChatMessage.sharedPostBody(
      postId: 'post-1',
      authorName: 'Chan',
      title: 'Weekend hiking',
      content: 'A short trail guide.',
    );
    ChatSharedPost? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            body: body,
            isMine: false,
            onSharedPostTap: (post) => opened = post,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Weekend hiking'));
    await tester.pump();

    expect(opened?.postId, 'post-1');
  });

  test('post detail image preview uses preview transition and download action',
      () {
    final source =
        File('lib/src/features/posts/presentation/post_detail_page.dart')
            .readAsStringSync();
    final carouselStart = source.indexOf('PageView.builder');
    final carouselEnd = source.indexOf('if (visibleImageUrls.length > 1)');
    expect(carouselStart, greaterThanOrEqualTo(0));
    expect(carouselEnd, greaterThan(carouselStart));

    final carouselSource = source.substring(carouselStart, carouselEnd);
    expect(carouselSource, isNot(contains('InteractiveViewer')));
    expect(carouselSource, contains('Listener('));
    expect(carouselSource, contains('_handleImagePointerDown'));
    expect(carouselSource, isNot(contains('_handleImagePointerMove')));
    expect(carouselSource, contains('onTap'));
    expect(
        carouselSource, contains('final heroTag = _postImageHeroTag(index);'));

    expect(source, contains('String _postImageHeroTag(int index)'));
    expect(source, contains('heroTags: List.generate'));
    expect(source, contains('Hero(tag: widget.heroTags[index], child: image)'));
    expect(source, contains('onClosing: _alignImagePreviewPage'));
    expect(source, contains('widget.onClosing(_index)'));
    expect(source, isNot(contains('widget.onIndexChanged(value)')));
    expect(source, contains('_isOfflineMode && post.imageUrls.isNotEmpty'));
    expect(source, contains('post.imageUrls.take(1).toList()'));
    expect(carouselSource, contains('NeverScrollableScrollPhysics'));
    expect(carouselSource, contains('previewEnabled: !_isOfflineMode'));
    expect(carouselSource, contains('onTap: _isOfflineMode'));
    expect(source, contains('_pageController.jumpToPage(0)'));
    expect(source, contains('if (visibleImageUrls.length > 1)'));
    expect(source, contains('visibleImageUrls.length,'));
    expect(source, contains('_pageController.jumpToPage(safeIndex)'));
    expect(source, isNot(contains('final oldController = _pageController')));
    expect(
        source, contains('_pageController = PageController(keepPage: false)'));
    expect(source, isNot(contains('index == _currentPage) return')));
    expect(source, isNot(contains('_PostDetailPreviewPinchBridge')));
    expect(source, isNot(contains('_buildSourcePinchSurface')));
    expect(source, isNot(contains('_postImageRect')));
    expect(source, contains('maxScale: 4.8'));
    expect(source, contains('boundaryMargin: const EdgeInsets.all(160)'));
    expect(source, contains('panEnabled: _canPanImage'));
    expect(source, contains('_canPanImage = scale > 1.01'));
    expect(source, contains('_settleToScale(4)'));
    expect(source, contains('_matrixWithPreservedViewportPoint'));
    expect(source, contains('targetTranslation'));
    expect(source, isNot(contains('end: _matrixForScale(scale, focalPoint)')));
    expect(source, contains('Curves.easeOutCubic'));
    expect(source, contains('minScale: 0.85'));
    expect(source, contains('backgroundColor: Colors.black'));
    expect(source, contains('_PostDetailPreviewHeader'));
    expect(source, contains('Color(0xB3000000)'));
    expect(source, isNot(contains('closeOnZoomOut')));
    expect(source, contains('onInteractionEnd:'));
    expect(source, contains('scale < 0.97'));
    expect(source, contains('onTap: _closePreview'));
    expect(source, contains('Icons.download_rounded'));
    expect(source, contains(r"'${_index + 1}/$total'"));
    expect(source, isNot(contains(r'${widget.title} ·')));
  });

  test('share sheet reuses Message page group avatar styling', () {
    final source =
        File('lib/src/features/posts/presentation/post_detail_page.dart')
            .readAsStringSync();

    expect(source, contains('GroupAvatar('));
    expect(source, isNot(contains('_groupPalette')));
    expect(source, contains('SliverGridDelegateWithFixedCrossAxisCount'));
    expect(source, contains('crossAxisCount: 3'));
    expect(
        source, contains('double _defaultSheetHeight(BuildContext context)'));
    expect(source, contains('screenHeight * 0.5'));
    expect(
      source,
      contains('view.padding.top / view.devicePixelRatio'),
    );
    expect(source, contains('onVerticalDragStart:'));
    expect(source, contains('onVerticalDragUpdate:'));
    expect(source, contains('onVerticalDragEnd: _handleSheetDragEnd'));
    expect(source, contains('_sheetDragHeight'));
    expect(source, contains('Duration.zero'));
    expect(source, contains('_isSheetExpanded = shouldExpand'));
    expect(source, contains('int get _recentContactRows'));
    expect(source, contains('height: gridHeight'));
    expect(source, contains('_recentShareContactsCache'));
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

  testWidgets('ChatPage filter chips show unread chat counts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          loadConversations: () async => [
            ChatConversation.fromMap({
              'id': 'direct-unread',
              'type': 'direct',
              'request_status': 'accepted',
              'unread_count': 2,
              'other_user_name': 'Chan',
            }),
            ChatConversation.fromMap({
              'id': 'group-unread',
              'type': 'group',
              'request_status': 'accepted',
              'unread_count': 1,
              'title': 'Study group',
            }),
          ],
          loadRequests: () async => [
            ChatConversation.fromMap({
              'id': 'request-unread',
              'type': 'direct',
              'request_status': 'pending',
              'unread_count': 1,
              'other_user_name': 'Request user',
            }),
          ],
          loadCounts: () async => const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('message-filter-count-unread')),
          )
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('message-filter-count-groups')),
          )
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('message-filter-count-requests')),
          )
          .data,
      '1',
    );
  });

  testWidgets('ChatPage filter chips hide zero unread counts', (tester) async {
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

    expect(find.byKey(const ValueKey('message-filter-count-unread')),
        findsNothing);
    expect(find.byKey(const ValueKey('message-filter-count-groups')),
        findsNothing);
    expect(find.byKey(const ValueKey('message-filter-count-requests')),
        findsNothing);
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
    final viewAll = tester.widget<Text>(find.text('View all chats'));
    expect(viewAll.style?.color, const Color(0xFF128C7E));

    await tester.tap(find.text('View all chats'));
    await tester.pumpAndSettle();

    expect(find.text('Alicia'), findsOneWidget);
  });

  testWidgets('Requests empty state keeps recent request helper copy',
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

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.text('No recent message requests'), findsOneWidget);
    expect(
      find.text("Requests older than 30 days aren't shown."),
      findsOneWidget,
    );
  });

  testWidgets('Notification section waits to mark read before system back pop',
      (tester) async {
    final readCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationSectionsPage(
                        initialSection: NotificationSection.activity,
                        loadNotifications: (_) async => const [],
                        markSectionRead: (_) => readCompleter.future,
                      ),
                    ),
                  );
                },
                child: const Text('Open activity'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open activity'));
    await tester.pumpAndSettle();

    expect(find.text('No activity'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('No activity'), findsOneWidget);

    readCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Open activity'), findsOneWidget);
  });

  test('ChatPage exposes badge callback for shell refreshes', () {
    final chatPageSource =
        File('lib/src/features/chat/presentation/chat_page.dart')
            .readAsStringSync();
    final shellSource =
        File('lib/src/features/shell/presentation/main_shell.dart')
            .readAsStringSync();

    expect(chatPageSource, contains('onBadgeCountChanged'));
    expect(shellSource, contains('ChatPage('));
    expect(shellSource, contains('onBadgeCountChanged'));
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

  testWidgets('ChatRoomPage shows unread divider before first unread message',
      (tester) async {
    final conversation = ChatConversation.fromMap({
      'id': 'unread-divider-test',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 2,
      'other_user_name': 'Ming',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: conversation,
          loadMessages: () async => [
            ChatMessage.fromMap({
              'id': 'm1',
              'conversation_id': 'unread-divider-test',
              'sender_id': 'u2',
              'body': 'older message',
              'created_at': '2026-06-29T10:00:00Z',
            }, currentUserId: 'u1'),
            ChatMessage.fromMap({
              'id': 'm2',
              'conversation_id': 'unread-divider-test',
              'sender_id': 'u2',
              'body': 'first unread',
              'created_at': '2026-06-29T10:01:00Z',
            }, currentUserId: 'u1'),
            ChatMessage.fromMap({
              'id': 'm3',
              'conversation_id': 'unread-divider-test',
              'sender_id': 'u2',
              'body': 'newest unread',
              'created_at': '2026-06-29T10:02:00Z',
            }, currentUserId: 'u1'),
          ],
          sendMessage: (_, __) async {},
          markRead: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 unread messages'), findsOneWidget);
    final olderY = tester.getTopLeft(find.text('older message')).dy;
    final dividerY = tester.getTopLeft(find.text('2 unread messages')).dy;
    final firstUnreadY = tester.getTopLeft(find.text('first unread')).dy;

    expect(olderY, lessThan(dividerY));
    expect(dividerY, lessThan(firstUnreadY));
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

  testWidgets('notification rows show unread dot and clear it after opening',
      (tester) async {
    final marked = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.followers,
          openFollowerProfile: (_) {},
          markNotificationRead: (notificationId) async {
            marked.add(notificationId);
          },
          loadNotifications: (_) async => [
            ChatNotification.fromMap({
              'id': 'follower-unread',
              'type': 'new_follower',
              'actor_id': 'user-follower-1',
              'title': 'New follower',
              'body': 'Someone started following you',
              'created_at': '2026-07-05T08:30:00',
              'profiles': {'name': 'Alicia'},
            }),
            ChatNotification.fromMap({
              'id': 'follower-read',
              'type': 'new_follower',
              'actor_id': 'user-follower-2',
              'title': 'New follower',
              'body': 'Someone started following you',
              'created_at': '2026-07-05T08:00:00',
              'read_at': '2026-07-05T09:00:00',
              'profiles': {'name': 'Ming'},
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('notification-unread-dot-follower-unread')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('notification-unread-dot-follower-read')),
        findsNothing);

    await tester.tap(find.text('Alicia'));
    await tester.pumpAndSettle();

    expect(marked, ['follower-unread']);
    expect(
        find.byKey(const ValueKey('notification-unread-dot-follower-unread')),
        findsNothing);
  });

  testWidgets('notification unread dot sits beside avatar without row shift',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.followers,
          openFollowerProfile: (_) {},
          loadNotifications: (_) async => [
            ChatNotification.fromMap({
              'id': 'follower-unread',
              'type': 'new_follower',
              'actor_id': 'user-follower-1',
              'title': 'New follower',
              'body': 'Someone started following you',
              'created_at': '2026-07-05T08:30:00',
              'profiles': {'name': 'Alicia'},
            }),
            ChatNotification.fromMap({
              'id': 'follower-read',
              'type': 'new_follower',
              'actor_id': 'user-follower-2',
              'title': 'New follower',
              'body': 'Someone started following you',
              'created_at': '2026-07-05T08:00:00',
              'read_at': '2026-07-05T09:00:00',
              'profiles': {'name': 'Ming'},
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dotFinder =
        find.byKey(const ValueKey('notification-unread-dot-follower-unread'));
    final dotRight = tester.getTopRight(dotFinder).dx;
    final unreadAvatarLeft =
        tester.getTopLeft(find.byType(ChatAvatar).first).dx;
    final readAvatarLeft = tester.getTopLeft(find.byType(ChatAvatar).last).dx;

    expect(unreadAvatarLeft, readAvatarLeft);
    expect(unreadAvatarLeft, lessThanOrEqualTo(24));
    expect(unreadAvatarLeft - dotRight, lessThanOrEqualTo(4));
    expect(find.text('New'), findsNothing);
    expect(find.byType(Divider), findsWidgets);
  });

  test('notification divider aligns with notification row text', () {
    final source = File(
      'lib/src/features/chat/presentation/notification_sections_page.dart',
    ).readAsStringSync();

    expect(source, contains('indent: 62'));
    expect(source, isNot(contains('indent: 78')));
    expect(source, isNot(contains('indent: 82')));
  });

  test('conversation rows place unread badge on preview line', () {
    final source = File('lib/src/features/chat/presentation/chat_widgets.dart')
        .readAsStringSync();
    final start = source.indexOf('class _ConversationTileState');
    final end = source.indexOf('class _ConversationPreviewLine', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final tileSource = source.substring(start, end);
    expect(tileSource, isNot(contains('ChatAvatarWithBadge')));
    expect(tileSource, isNot(contains('_GroupAvatarWithBadge')));
    expect(tileSource, isNot(contains('UnreadBadge(count: unreadCount)')));
    expect(tileSource, isNot(contains('EdgeInsets.only(right: 8)')));
    expect(tileSource, contains('unreadCount: conversation.unreadCount'));
    expect(tileSource, contains('_ConversationPreviewLine'));
  });

  test('chat room supports initial unread target and jump to bottom button',
      () {
    final source =
        File('lib/src/features/chat/presentation/chat_room_page.dart')
            .readAsStringSync();

    expect(source, contains('_initialScrollDone'));
    expect(source, contains('_scrollToUnreadDividerOrLatest'));
    expect(source, contains('jump-to-bottom-button'));
    expect(source, contains('conversation.unreadCount'));
    expect(source, contains('_handleInputFocusChanged'));
    expect(source, contains('void didChangeMetrics()'));
    expect(source, contains('Duration(milliseconds: 300)'));
    expect(source, contains('_UnreadMessagesDivider'));
    expect(source, contains('color: Colors.white'));
    expect(source, contains('color: Color(0xFF111827)'));
    expect(source, isNot(contains('color: Color(0xFFB7D8CF)')));
    expect(source, contains('_scrollToUnreadDividerOrLatest'));
    expect(source, contains('_setJumpToBottomVisible(false)'));
    expect(source, contains('hasContentDimensions'));
    expect(source, contains('reverse: true'));
    expect(source, contains('position.minScrollExtent'));
    expect(source,
        isNot(contains('position.maxScrollExtent - position.pixels > 160')));
    expect(source, isNot(contains('setState(() => _messagesFuture')));
  });

  test('notification page refresh resets follower action state', () {
    final source = File(
      'lib/src/features/chat/presentation/notification_sections_page.dart',
    ).readAsStringSync();

    expect(source, contains('int _refreshGeneration = 0;'));
    expect(source, contains('_refreshGeneration += 1;'));
    expect(
      source,
      contains('follower-action-\${notification.id}-\$refreshGeneration'),
    );
  });

  test('follow back uses follow-only profile flow and not toggle helper', () {
    final source = File(
      'lib/src/features/chat/presentation/notification_sections_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _follow()');
    final end = source.indexOf('Future<void> _message()', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final followSource = source.substring(start, end);
    expect(followSource, contains('_profileRepo.followUser'));
    expect(followSource, isNot(contains('_profileRepo.toggleFollow')));
    expect(followSource, isNot(contains('_repo.followUser')));
    expect(followSource, isNot(contains("Text('No internet connection')")));
    expect(followSource, isNot(contains('setState(() => _future')));
    expect(followSource, contains('_future = Future.value(true);'));
    expect(
      followSource,
      matches(
        RegExp(
          r'try\s*\{\s*await widget\.onNotificationRead\(\);\s*\} catch \(_\) \{\}',
        ),
      ),
    );
    expect(
      followSource.indexOf('_profileRepo.followUser'),
      lessThan(followSource.indexOf('await widget.onNotificationRead')),
    );
  });

  test('activity notifications pass comment id into post detail page', () {
    final source = File(
      'lib/src/features/chat/presentation/notification_sections_page.dart',
    ).readAsStringSync();

    expect(source, contains('initialCommentId: notification.commentId'));
  });

  testWidgets('NotificationSectionsPage refreshes when app resumes',
      (tester) async {
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSectionsPage(
          initialSection: NotificationSection.followers,
          openFollowerProfile: (_) {},
          loadNotifications: (_) async {
            loadCount += 1;
            if (loadCount == 1) return const <ChatNotification>[];
            return [
              ChatNotification.fromMap({
                'id': 'follower-resumed',
                'type': 'new_follower',
                'actor_id': 'user-follower-1',
                'title': 'New follower',
                'body': 'Someone started following you',
                'created_at': '2026-07-05T08:30:00',
                'profiles': {'name': 'Alicia'},
              }),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recent followers'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('Alicia'), findsOneWidget);
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
