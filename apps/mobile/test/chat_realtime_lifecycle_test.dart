import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _methodSource(String source, String start, String? next) {
  final startIndex = source.indexOf(start);
  expect(startIndex, greaterThanOrEqualTo(0), reason: '$start is missing');
  final endIndex =
      next == null ? source.length : source.indexOf(next, startIndex);
  expect(endIndex, greaterThan(startIndex), reason: '$next is missing');
  return source.substring(startIndex, endIndex);
}

void main() {
  final repositorySource = File(
    'lib/src/features/chat/data/chat_repository.dart',
  ).readAsStringSync();

  test('chat home subscription filters notification rows to current user', () {
    final source = _methodSource(
      repositorySource,
      'RealtimeChannel subscribeToChatHomeChanges',
      'RealtimeChannel subscribeToConversationChanges',
    );

    expect(source, contains("table: 'chat_conversations'"));
    expect(source, contains("table: 'chat_conversation_members'"));
    expect(source, contains("table: 'chat_messages'"));
    expect(source, contains("table: 'notifications'"));
    expect(source, contains("column: 'user_id'"));
    expect(source, contains('value: currentUserId'));
  });

  test('room subscription filters every source to its conversation', () {
    final source = _methodSource(
      repositorySource,
      'RealtimeChannel subscribeToConversationChanges',
      'RealtimeChannel subscribeToNotificationChanges',
    );

    expect(source, contains("column: 'id'"));
    expect(source, contains("column: 'conversation_id'"));
    expect(source, contains('value: conversationId'));
    expect(source, isNot(contains("table: 'notifications'")));
  });

  test('notification subscription filters rows to current user', () {
    final source = _methodSource(
      repositorySource,
      'RealtimeChannel subscribeToNotificationChanges',
      'Future<void> unsubscribe',
    );

    expect(source, contains("table: 'notifications'"));
    expect(source, contains("column: 'user_id'"));
    expect(source, contains('value: currentUserId'));
  });

  test('chat room owns one scoped channel and one refresh coordinator', () {
    final source = File(
      'lib/src/features/chat/presentation/chat_room_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('late final ChatRefreshCoordinator _refreshCoordinator;'),
    );
    expect(source, contains('_repo.subscribeToConversationChanges('));
    expect(source, contains('conversationId: _conversation.id'));
    expect(
      source,
      contains('onChange: (_) => _refreshCoordinator.schedule()'),
    );
    expect(source, contains('_refreshCoordinator.dispose();'));
    expect(source, isNot(contains('_repo.subscribeToChatChanges(')));
  });
}
