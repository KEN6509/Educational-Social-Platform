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

  test('notification page coalesces realtime refreshes and disposes its owner',
      () {
    final source = File(
      'lib/src/features/chat/presentation/notification_sections_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('late final ChatRefreshCoordinator _refreshCoordinator;'),
    );
    expect(source, contains('onChange: (_) => _refreshCoordinator.schedule()'));
    expect(source, contains('_refreshCoordinator.dispose();'));
    expect(source, contains('Future<void> _performRefresh()'));
  });

  test(
      'chat home owns continuous badge realtime and shell does not duplicate it',
      () {
    final chatSource = File(
      'lib/src/features/chat/presentation/chat_page.dart',
    ).readAsStringSync();
    final shellSource = File(
      'lib/src/features/shell/presentation/main_shell.dart',
    ).readAsStringSync();

    expect(chatSource, contains('with WidgetsBindingObserver'));
    expect(chatSource, contains('_repo.subscribeToChatHomeChanges('));
    expect(
      chatSource,
      contains('onChange: (_) => _refreshCoordinator.schedule()'),
    );
    expect(chatSource, contains('void didChangeAppLifecycleState('));
    expect(chatSource, contains('_refreshCoordinator.dispose();'));
    expect(shellSource, isNot(contains('_notificationBadgeChannel')));
    expect(
      shellSource,
      isNot(contains("channelName: 'main-shell-notification-badge'")),
    );
  });

  test('legacy broad chat subscription is removed after both callers migrate',
      () {
    final repositorySource = File(
      'lib/src/features/chat/data/chat_repository.dart',
    ).readAsStringSync();

    expect(
      repositorySource,
      isNot(contains('RealtimeChannel subscribeToChatChanges')),
    );
  });

  test('chat realtime refresh does not reload eligible people', () {
    final source = File(
      'lib/src/features/chat/presentation/chat_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _performHomeRefresh()');
    final end = source.indexOf('Future<void> _refresh(', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(
      source.substring(start, end),
      isNot(contains('_loadEligiblePeople')),
    );
  });
}
