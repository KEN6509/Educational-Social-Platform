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
}
