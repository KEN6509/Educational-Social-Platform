import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = 'lib/src/features/chat/presentation';

  test('message bubbles live in their feature-local part', () {
    final root = File('$path/chat_widgets.dart').readAsStringSync();
    final bubbleFile = File('$path/chat_message_bubbles.dart');

    expect(root, contains("part 'chat_message_bubbles.dart';"));
    expect(bubbleFile.existsSync(), isTrue);
    if (!bubbleFile.existsSync()) return;

    final bubbles = bubbleFile.readAsStringSync();
    expect(bubbles, startsWith("part of 'chat_widgets.dart';"));
    expect(bubbles, contains('class ChatMessageBubble'));
    expect(bubbles, contains('class _SharedPostBubbleContent'));
    expect(bubbles, contains('class _SharedPostImageCardBody'));
    expect(bubbles, contains('class _SharedPostTextCardBody'));
    expect(bubbles, contains('class _InlineBubbleTextWithTime'));
    expect(bubbles, contains('TextStyle _bubbleTimestampStyle()'));
    expect(root, isNot(contains('class ChatMessageBubble')));
    expect(root, isNot(contains('class _InlineBubbleTextWithTime')));
  });

  test('chat message media lives in its feature-local part', () {
    final root = File('$path/chat_widgets.dart').readAsStringSync();
    final mediaFile = File('$path/chat_message_media.dart');

    expect(root, contains("part 'chat_message_media.dart';"));
    expect(mediaFile.existsSync(), isTrue);
    if (!mediaFile.existsSync()) return;

    final media = mediaFile.readAsStringSync();
    expect(media, startsWith("part of 'chat_widgets.dart';"));
    expect(media, contains('class _ImageBubbleContent'));
    expect(media, contains('class _SingleImageBubbleThumbnail'));
    expect(media, contains('class _ChatImagePreviewPage'));
    expect(media, contains('class _ChatImageLoadError'));
    expect(media, contains('class _ImageBubbleGrid'));
    expect(media, contains('class _ChatImageThumbnailLoadError'));
    expect(root, isNot(contains('class _ImageBubbleContent')));
    expect(root, isNot(contains('class _ChatImagePreviewPage')));
  });

  test('chat list widgets live in their feature-local part', () {
    final root = File('$path/chat_widgets.dart').readAsStringSync();
    final listFile = File('$path/chat_list_widgets.dart');

    expect(root, contains("part 'chat_list_widgets.dart';"));
    expect(listFile.existsSync(), isTrue);
    if (!listFile.existsSync()) return;

    final list = listFile.readAsStringSync();
    expect(list, startsWith("part of 'chat_widgets.dart';"));
    expect(list, contains('class ChatAvatar'));
    expect(list, contains('class GroupAvatar'));
    expect(list, contains('class ChatSearchField'));
    expect(list, contains('class ConversationTile'));
    expect(list, contains('class ChatParticipantRow'));
    expect(list, contains('class ChatNoResultsState'));
    expect(list, contains('class ChatEmptyState'));
    expect(list, contains('class NotificationEntryCard'));
    expect(root, isNot(contains('class ChatAvatar')));
    expect(root, isNot(contains('class ConversationTile')));
  });

  test('chat room visual widgets live in their feature-local part', () {
    final root = File('$path/chat_room_page.dart').readAsStringSync();
    final roomFile = File('$path/chat_room_widgets.dart');

    expect(root, contains("part 'chat_room_widgets.dart';"));
    expect(roomFile.existsSync(), isTrue);
    if (!roomFile.existsSync()) return;

    final room = roomFile.readAsStringSync();
    expect(room, startsWith("part of 'chat_room_page.dart';"));
    expect(room, contains('class _MessageList'));
    expect(room, contains('class _JumpToBottomButton'));
    expect(room, contains('class _MentionSuggestionsPanel'));
    expect(room, contains('class _DateSeparator'));
    expect(room, contains('class _UnreadMessagesDivider'));
    expect(room, contains('class _WhatsAppRoomBackground'));
    expect(room, contains('class _ChatWallpaperPainter'));
    expect(root, isNot(contains('class _MessageList')));
    expect(root, isNot(contains('class _ChatWallpaperPainter')));
  });
}
