# Mobile Chat Realtime and Refresh Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mobile chat realtime listeners refresh only their intended scope and combine burst events without overlapping database work or changing visible chat behavior.

**Architecture:** Add one pure-Dart, feature-local refresh coordinator that debounces realtime bursts and serializes asynchronous refreshes. Keep page State classes as UI owners, expose purpose-specific Supabase subscription methods from `ChatRepository`, and make the always-mounted `ChatPage` the continuous source for the shell chat badge.

**Tech Stack:** Flutter, Dart, Material 3, Supabase Flutter realtime, SharedPreferences, flutter_test

---

## Scope and working rules

- Work in the original `C:\Chan Ming Jiang\Degree\Sem 5\CyanZone` folder on
  `refactor/mobile-architecture-optimization`; do not create a worktree.
- Preserve all chat UI values, public routes, direct-message follow
  enforcement, group rules, mentions, notification behavior, caches, and
  navigation.
- Do not change SQL, Firebase, moderation, or dependencies.
- Add tests before each behavior-changing implementation.
- Use focused tests after every task and commit each passing task separately.
- Use `apply_patch` for file edits and run terminal commands directly in the
  user's terminal.

## File structure

### Create

- `apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart`
  - owns debounce, in-flight serialization, one trailing refresh, error
    containment, and disposal for chat refresh work.
- `apps/mobile/test/chat_refresh_coordinator_test.dart`
  - proves coordinator timing and lifecycle behavior without Flutter widgets.
- `apps/mobile/test/chat_realtime_lifecycle_test.dart`
  - protects purpose-specific repository filters and page/channel ownership.

### Modify

- `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
  - replaces ambiguous screen use of the broad subscription with chat-home,
    conversation, and current-user notification subscription methods.
- `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
  - routes room realtime and successful-send reloads through one coordinator.
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
  - coalesces realtime refreshes and serializes immediate refreshes.
- `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
  - owns continuous badge refresh, observes resume, starts independent reads
    concurrently, and avoids realtime reloads of eligible people.
- `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
  - removes its duplicate continuous notification channel and keeps the last
    badge reported by `ChatPage`.
- `apps/mobile/test/chat_repository_test.dart`
  - updates realtime repository and shell ownership expectations.
- `apps/mobile/test/chat_widgets_test.dart`
  - adds chat-home concurrency and resume coverage and updates lifecycle source
    expectations.

---

### Task 1: Add the feature-local refresh coordinator

**Files:**

- Create: `apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart`
- Create: `apps/mobile/test/chat_refresh_coordinator_test.dart`

- [ ] **Step 1: Write the failing coordinator tests**

Create `apps/mobile/test/chat_refresh_coordinator_test.dart`:

```dart
import 'dart:async';

import 'package:cyanzone_mobile/src/features/chat/application/chat_refresh_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces scheduled requests inside the debounce window', () async {
    var refreshCount = 0;
    final coordinator = ChatRefreshCoordinator(
      debounce: const Duration(milliseconds: 10),
      refresh: () async {
        refreshCount += 1;
      },
    );

    coordinator.schedule();
    coordinator.schedule();
    coordinator.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(refreshCount, 1);
    coordinator.dispose();
  });

  test('serializes refreshes and allows one trailing refresh', () async {
    final firstRefresh = Completer<void>();
    var refreshCount = 0;
    var activeRefreshes = 0;
    var maximumActiveRefreshes = 0;
    final coordinator = ChatRefreshCoordinator(
      debounce: Duration.zero,
      refresh: () async {
        refreshCount += 1;
        activeRefreshes += 1;
        maximumActiveRefreshes =
            activeRefreshes > maximumActiveRefreshes
                ? activeRefreshes
                : maximumActiveRefreshes;
        if (refreshCount == 1) await firstRefresh.future;
        activeRefreshes -= 1;
      },
    );

    final cycle = coordinator.refreshNow();
    await Future<void>.delayed(Duration.zero);
    coordinator.refreshNow();
    coordinator.refreshNow();

    expect(refreshCount, 1);
    firstRefresh.complete();
    await cycle;

    expect(refreshCount, 2);
    expect(maximumActiveRefreshes, 1);
    coordinator.dispose();
  });

  test('immediate refresh cancels a pending debounce', () async {
    var refreshCount = 0;
    final coordinator = ChatRefreshCoordinator(
      debounce: const Duration(milliseconds: 20),
      refresh: () async {
        refreshCount += 1;
      },
    );

    coordinator.schedule();
    await coordinator.refreshNow();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(refreshCount, 1);
    coordinator.dispose();
  });

  test('dispose cancels delayed and future refresh work', () async {
    var refreshCount = 0;
    final coordinator = ChatRefreshCoordinator(
      debounce: const Duration(milliseconds: 10),
      refresh: () async {
        refreshCount += 1;
      },
    );

    coordinator.schedule();
    coordinator.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await coordinator.refreshNow();

    expect(refreshCount, 0);
  });

  test('a failed refresh does not prevent the next refresh', () async {
    var refreshCount = 0;
    final errors = <Object>[];
    final coordinator = ChatRefreshCoordinator(
      refresh: () async {
        refreshCount += 1;
        if (refreshCount == 1) throw StateError('temporary failure');
      },
      onError: (error, _) => errors.add(error),
    );

    await coordinator.refreshNow();
    await coordinator.refreshNow();

    expect(refreshCount, 2);
    expect(errors, hasLength(1));
    coordinator.dispose();
  });
}
```

- [ ] **Step 2: Run the tests and verify the missing-file failure**

Run from `apps/mobile`:

```powershell
flutter test test/chat_refresh_coordinator_test.dart --no-pub --reporter expanded
```

Expected: FAIL because
`features/chat/application/chat_refresh_coordinator.dart` does not exist.

- [ ] **Step 3: Implement the minimal coordinator**

Create
`apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart`:

```dart
import 'dart:async';

typedef ChatRefreshTask = Future<void> Function();
typedef ChatRefreshErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

final class ChatRefreshCoordinator {
  ChatRefreshCoordinator({
    required ChatRefreshTask refresh,
    this.debounce = const Duration(milliseconds: 120),
    ChatRefreshErrorHandler? onError,
  })  : _refresh = refresh,
        _onError = onError;

  final ChatRefreshTask _refresh;
  final ChatRefreshErrorHandler? _onError;
  final Duration debounce;

  Timer? _timer;
  Completer<void>? _cycleCompleter;
  bool _pending = false;
  bool _disposed = false;

  void schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(refreshNow());
    });
  }

  Future<void> refreshNow() {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    _pending = true;

    final activeCycle = _cycleCompleter;
    if (activeCycle != null) return activeCycle.future;

    final cycle = Completer<void>();
    _cycleCompleter = cycle;
    unawaited(_drain(cycle));
    return cycle.future;
  }

  Future<void> _drain(Completer<void> cycle) async {
    try {
      while (_pending && !_disposed) {
        _pending = false;
        try {
          await _refresh();
        } catch (error, stackTrace) {
          _onError?.call(error, stackTrace);
        }
      }
    } finally {
      if (identical(_cycleCompleter, cycle)) {
        _cycleCompleter = null;
      }
      if (!cycle.isCompleted) cycle.complete();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending = false;
    _timer?.cancel();
    _timer = null;
  }
}
```

- [ ] **Step 4: Format and run the coordinator tests**

```powershell
dart format lib/src/features/chat/application/chat_refresh_coordinator.dart test/chat_refresh_coordinator_test.dart
flutter test test/chat_refresh_coordinator_test.dart --no-pub --reporter expanded
```

Expected: five tests PASS.

- [ ] **Step 5: Commit the coordinator checkpoint**

```powershell
git add apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart apps/mobile/test/chat_refresh_coordinator_test.dart
git commit -m "refactor(mobile): add chat refresh coordinator"
```

---

### Task 2: Add purpose-specific realtime subscriptions

**Files:**

- Create: `apps/mobile/test/chat_realtime_lifecycle_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart:825-875`
- Modify: `apps/mobile/test/chat_repository_test.dart:500-600`

- [ ] **Step 1: Write failing subscription contract tests**

Create `apps/mobile/test/chat_realtime_lifecycle_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _methodSource(String source, String start, String? next) {
  final startIndex = source.indexOf(start);
  expect(startIndex, greaterThanOrEqualTo(0), reason: '$start is missing');
  final endIndex = next == null ? source.length : source.indexOf(next, startIndex);
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
}
```

In `apps/mobile/test/chat_repository_test.dart`, replace the old assertion for
`RealtimeChannel subscribeToChatChanges` with:

```dart
expect(
  repositorySource,
  contains('RealtimeChannel subscribeToChatHomeChanges'),
);
expect(
  repositorySource,
  contains('RealtimeChannel subscribeToConversationChanges'),
);
```

Update the end marker in the group-suggestion source test from
`RealtimeChannel subscribeToChatChanges` to
`RealtimeChannel subscribeToChatHomeChanges`.

- [ ] **Step 2: Run the contract tests and verify failure**

```powershell
flutter test test/chat_realtime_lifecycle_test.dart test/chat_repository_test.dart --no-pub --reporter expanded
```

Expected: FAIL because the two purpose-specific methods and their filters are
missing.

- [ ] **Step 3: Add the purpose-specific repository subscription methods**

In `ChatRepository`, insert these two methods immediately before the existing
`subscribeToChatChanges` method and add the current-user filter to
`subscribeToNotificationChanges`:

```dart
RealtimeChannel subscribeToChatHomeChanges({
  required String channelName,
  required void Function(PostgresChangePayload payload) onChange,
}) {
  final currentUserId = _requireCurrentUserId();
  return _client
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_conversations',
        callback: onChange,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_conversation_members',
        callback: onChange,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_messages',
        callback: onChange,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: currentUserId,
        ),
        callback: onChange,
      )
      .subscribe();
}

RealtimeChannel subscribeToConversationChanges({
  required String channelName,
  required String conversationId,
  required void Function(PostgresChangePayload payload) onChange,
}) {
  return _client
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_conversations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: conversationId,
        ),
        callback: onChange,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_conversation_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: onChange,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: onChange,
      )
      .subscribe();
}

RealtimeChannel subscribeToNotificationChanges({
  required String channelName,
  required void Function(PostgresChangePayload payload) onChange,
}) {
  final currentUserId = _requireCurrentUserId();
  return _client
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: currentUserId,
        ),
        callback: onChange,
      )
      .subscribe();
}
```

Keep the existing `subscribeToChatChanges` method temporarily so
`ChatRoomPage` and `ChatPage` continue to compile until Tasks 3 and 5 migrate
them. Keep `unsubscribe(RealtimeChannel channel)` unchanged.

- [ ] **Step 4: Format and run repository contract tests**

```powershell
dart format lib/src/features/chat/data/chat_repository.dart test/chat_realtime_lifecycle_test.dart test/chat_repository_test.dart
flutter test test/chat_realtime_lifecycle_test.dart test/chat_repository_test.dart --no-pub --reporter expanded
```

Expected: PASS, with all existing pages still compiling through the temporary
legacy method.

- [ ] **Step 5: Commit the subscription checkpoint**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/test/chat_realtime_lifecycle_test.dart apps/mobile/test/chat_repository_test.dart
git commit -m "refactor(mobile): scope chat realtime subscriptions"
```

---

### Task 3: Route chat-room refreshes through the coordinator

**Files:**

- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart:1-165,500-640`
- Modify: `apps/mobile/test/chat_realtime_lifecycle_test.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add failing room ownership assertions**

Append inside `main()` in `chat_realtime_lifecycle_test.dart`:

```dart
test('chat room owns one scoped channel and one refresh coordinator', () {
  final source = File(
    'lib/src/features/chat/presentation/chat_room_page.dart',
  ).readAsStringSync();

  expect(source, contains('late final ChatRefreshCoordinator _refreshCoordinator;'));
  expect(source, contains('_repo.subscribeToConversationChanges('));
  expect(source, contains('conversationId: _conversation.id'));
  expect(source, contains('onChange: (_) => _refreshCoordinator.schedule()'));
  expect(source, contains('_refreshCoordinator.dispose();'));
  expect(source, isNot(contains('_repo.subscribeToChatChanges(')));
});
```

- [ ] **Step 2: Run the room contract test and verify failure**

```powershell
flutter test test/chat_realtime_lifecycle_test.dart --no-pub --reporter expanded
```

Expected: FAIL because `ChatRoomPage` still owns the broad callback.

- [ ] **Step 3: Add coordinator ownership to `ChatRoomPage`**

Add this import:

```dart
import '../application/chat_refresh_coordinator.dart';
```

Add this State field beside `_channel`:

```dart
late final ChatRefreshCoordinator _refreshCoordinator;
```

In `initState`, initialize the coordinator immediately after
`_messagesFuture = _load();`:

```dart
_refreshCoordinator = ChatRefreshCoordinator(
  refresh: _refreshMessages,
  onError: (error, _) {
    assert(() {
      debugPrint('Chat room refresh failed: $error');
      return true;
    }());
  },
);
```

Replace the room subscription with:

```dart
_channel = _repo.subscribeToConversationChanges(
  channelName: 'chat-room-${_conversation.id}',
  conversationId: _conversation.id,
  onChange: (_) => _refreshCoordinator.schedule(),
);
```

Add this method immediately after `_load()`:

```dart
Future<void> _refreshMessages() async {
  if (!mounted) return;
  final nextMessages = _load();
  setState(() => _messagesFuture = nextMessages);
  await nextMessages;
}
```

At the start of `dispose`, before closing the channel, add:

```dart
_refreshCoordinator.dispose();
```

- [ ] **Step 4: Use the same immediate path after text and image sends**

In both `_send()` and `_sendImage()`, replace the duplicated
`final nextMessages = _load()` and `_messagesFuture` assignment with:

```dart
unawaited(_refreshCoordinator.refreshNow());
_pinToBottomAfterLayout();
```

Do not change send validation, error mapping, `_isSending`, `_isPickingImage`,
or relationship enforcement.

- [ ] **Step 5: Format and run the room-focused tests**

```powershell
dart format lib/src/features/chat/presentation/chat_room_page.dart test/chat_realtime_lifecycle_test.dart
flutter test test/chat_realtime_lifecycle_test.dart test/chat_widgets_test.dart --no-pub --reporter expanded
```

Expected: PASS with all existing room sending, media, mention, selection, and
scroll tests unchanged.

- [ ] **Step 6: Commit the room checkpoint**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/test/chat_realtime_lifecycle_test.dart
git commit -m "refactor(mobile): coordinate chat room refreshes"
```

---

### Task 4: Coordinate notification-section refreshes

**Files:**

- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart:1-130`
- Modify: `apps/mobile/test/chat_realtime_lifecycle_test.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add failing notification ownership assertions**

Append inside `main()` in `chat_realtime_lifecycle_test.dart`:

```dart
test('notification page coalesces realtime refreshes and disposes its owner', () {
  final source = File(
    'lib/src/features/chat/presentation/notification_sections_page.dart',
  ).readAsStringSync();

  expect(source, contains('late final ChatRefreshCoordinator _refreshCoordinator;'));
  expect(source, contains('onChange: (_) => _refreshCoordinator.schedule()'));
  expect(source, contains('_refreshCoordinator.dispose();'));
  expect(source, contains('Future<void> _performRefresh()'));
});
```

- [ ] **Step 2: Run the notification contract test and verify failure**

```powershell
flutter test test/chat_realtime_lifecycle_test.dart --no-pub --reporter expanded
```

Expected: FAIL because the page refreshes directly from its realtime callback.

- [ ] **Step 3: Add the coordinator to `NotificationSectionsPage`**

Add `dart:async` and the application import:

```dart
import 'dart:async';

import '../application/chat_refresh_coordinator.dart';
```

Add this State field:

```dart
late final ChatRefreshCoordinator _refreshCoordinator;
```

Initialize it in `initState` after `_future = _load();`:

```dart
_refreshCoordinator = ChatRefreshCoordinator(
  refresh: _performRefresh,
);
```

Change only the realtime callback to the delayed path:

```dart
onChange: (_) => _refreshCoordinator.schedule(),
```

Replace `_refreshNotifications` with these methods:

```dart
Future<void> _performRefresh() async {
  if (!mounted) return;
  final next = _load();
  setState(() {
    _refreshGeneration += 1;
    _future = next;
  });
  try {
    await next;
  } catch (_) {
    // FutureBuilder retains the existing visible error behavior.
  }
}

void _refreshNotifications() {
  unawaited(_refreshCoordinator.refreshNow());
}
```

Keep all existing `_refreshNotifications()` call sites unchanged so navigation,
deletion, follow, read, and resume actions remain immediate.

At the start of `dispose`, before closing the channel, add:

```dart
_refreshCoordinator.dispose();
```

- [ ] **Step 4: Format and run notification-focused tests**

```powershell
dart format lib/src/features/chat/presentation/notification_sections_page.dart test/chat_realtime_lifecycle_test.dart
flutter test test/chat_realtime_lifecycle_test.dart test/chat_widgets_test.dart --no-pub --reporter expanded
```

Expected: PASS, including the resume refresh and follower-action generation
tests.

- [ ] **Step 5: Commit the notification checkpoint**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/test/chat_realtime_lifecycle_test.dart
git commit -m "refactor(mobile): coordinate notification refreshes"
```

---

### Task 5: Make chat home the continuous badge owner

**Files:**

- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart:1-280,560-610`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart:825-920`
- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart:1-225`
- Modify: `apps/mobile/test/chat_realtime_lifecycle_test.dart`
- Modify: `apps/mobile/test/chat_repository_test.dart:530-605`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add failing chat-home concurrency and resume widget tests**

`chat_widgets_test.dart` already imports `dart:async`. Add:

```dart
testWidgets('ChatPage starts conversation and count reads concurrently',
    (tester) async {
  SharedPreferences.setMockInitialValues({});
  final releaseConversations = Completer<void>();
  var conversationStarted = false;
  var countsStarted = false;

  await tester.pumpWidget(
    MaterialApp(
      home: ChatPage(
        loadConversations: () async {
          conversationStarted = true;
          await releaseConversations.future;
          return const <ChatConversation>[];
        },
        loadCounts: () async {
          countsStarted = true;
          return const <NotificationSection, int>{};
        },
      ),
    ),
  );
  await tester.pump();

  expect(conversationStarted, isTrue);
  expect(countsStarted, isTrue);

  releaseConversations.complete();
  await tester.pumpAndSettle();
});

testWidgets('ChatPage refreshes home data when the app resumes',
    (tester) async {
  SharedPreferences.setMockInitialValues({});
  var conversationLoads = 0;
  var countLoads = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: ChatPage(
        loadConversations: () async {
          conversationLoads += 1;
          return const <ChatConversation>[];
        },
        loadCounts: () async {
          countLoads += 1;
          return const <NotificationSection, int>{};
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();

  expect(conversationLoads, 2);
  expect(countLoads, 2);
});
```

- [ ] **Step 2: Add failing ownership assertions**

Append inside `main()` in `chat_realtime_lifecycle_test.dart`:

```dart
test('chat home owns continuous badge realtime and shell does not duplicate it', () {
  final chatSource = File(
    'lib/src/features/chat/presentation/chat_page.dart',
  ).readAsStringSync();
  final shellSource = File(
    'lib/src/features/shell/presentation/main_shell.dart',
  ).readAsStringSync();

  expect(chatSource, contains('with WidgetsBindingObserver'));
  expect(chatSource, contains('_repo.subscribeToChatHomeChanges('));
  expect(chatSource, contains('onChange: (_) => _refreshCoordinator.schedule()'));
  expect(chatSource, contains('void didChangeAppLifecycleState('));
  expect(chatSource, contains('_refreshCoordinator.dispose();'));
  expect(shellSource, isNot(contains('_notificationBadgeChannel')));
  expect(shellSource, isNot(contains("channelName: 'main-shell-notification-badge'")));
});

test('legacy broad chat subscription is removed after both callers migrate', () {
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
```

In `chat_repository_test.dart`, replace the old
`main shell owns foreground notification badge realtime lifecycle` test with:

```dart
test('chat page owns continuous badge realtime lifecycle', () {
  final chatSource = File(
    'lib/src/features/chat/presentation/chat_page.dart',
  ).readAsStringSync();
  final shellSource = File(
    'lib/src/features/shell/presentation/main_shell.dart',
  ).readAsStringSync();

  expect(chatSource, contains('with WidgetsBindingObserver'));
  expect(chatSource, contains('subscribeToChatHomeChanges'));
  expect(chatSource, contains('AppLifecycleState.resumed'));
  expect(chatSource, contains('_repo.unsubscribe(channel)'));
  expect(shellSource, isNot(contains('subscribeToNotificationChanges')));
  expect(shellSource, contains('chatBadgeCount: _chatBadgeCount'));
  expect(shellSource, contains('_handleChatBadgeCountChanged'));
});
```

- [ ] **Step 3: Run the new tests and verify failure**

```powershell
flutter test test/chat_realtime_lifecycle_test.dart test/chat_widgets_test.dart test/chat_repository_test.dart --no-pub --reporter expanded
```

Expected: FAIL because reads are sequential, `ChatPage` is not a lifecycle
observer, and `MainShell` still owns the duplicate channel.

- [ ] **Step 4: Start chat-home reads concurrently while preserving fallbacks**

Add to `chat_page.dart`:

```dart
import 'dart:async';
```

Add the coordinator import:

```dart
import '../application/chat_refresh_coordinator.dart';
```

Change the State declaration and add the field:

```dart
class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  // Existing cache fields remain unchanged.
  late final ChatRefreshCoordinator _refreshCoordinator;
```

Replace `_load()` with these three methods:

```dart
Future<_ChatHomeState> _load() async {
  await _restoreCachedHome();
  final conversationsFuture = _loadConversations();
  final countsFuture = _loadCounts();
  final conversations = await conversationsFuture;
  final counts = await countsFuture;

  final homeState = _ChatHomeState(
    conversations: conversations,
    counts: counts,
  );
  widget.onBadgeCountChanged?.call(
    ChatRepository.bottomChatBadgeCount(
      notificationCounts: counts,
      conversations: conversations,
    ),
  );
  return homeState;
}

Future<List<ChatConversation>> _loadConversations() async {
  try {
    final conversations = await (widget.loadConversations?.call() ??
        _repo.fetchConversations());
    _cachedConversations = conversations.take(10).toList();
    await _saveConversationCache(
      _conversationsCacheKey,
      _cachedConversations,
    );
    return conversations;
  } catch (_) {
    return _cachedConversations;
  }
}

Future<Map<NotificationSection, int>> _loadCounts() async {
  try {
    final counts = await (widget.loadCounts?.call() ??
        _repo.fetchUnreadNotificationCounts());
    _cachedCounts = counts;
    await _saveCountsCache(counts);
    return counts;
  } catch (_) {
    return _cachedCounts;
  }
}
```

- [ ] **Step 5: Add chat-home lifecycle and coordinator ownership**

In `initState`, register the observer, initialize the coordinator after
`_future`, and use the home subscription:

```dart
WidgetsBinding.instance.addObserver(this);
_future = _load();
_refreshCoordinator = ChatRefreshCoordinator(
  refresh: _performHomeRefresh,
);
_eligiblePeopleFuture =
    _shouldUseInjectedData ? Future.value(const []) : _loadEligiblePeople();
if (!_shouldUseInjectedData) {
  _channel = _repo.subscribeToChatHomeChanges(
    channelName: 'chat-home',
    onChange: (_) => _refreshCoordinator.schedule(),
  );
}
```

At the start of `dispose`, add:

```dart
WidgetsBinding.instance.removeObserver(this);
_refreshCoordinator.dispose();
```

Add:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    unawaited(_refreshCoordinator.refreshNow());
  }
}

Future<void> _performHomeRefresh() async {
  if (!mounted) return;
  final next = _load();
  setState(() => _future = next);
  await next;
}

Future<void> _refresh({bool includeEligiblePeople = true}) async {
  if (includeEligiblePeople && !_shouldUseInjectedData && mounted) {
    setState(() => _eligiblePeopleFuture = _loadEligiblePeople());
  }
  await _refreshCoordinator.refreshNow();
}
```

Delete the old synchronous `_refresh()` implementation. Change the pull
refresh callback to:

```dart
onRefresh: _refresh,
```

After returning from `NotificationSectionsPage`, use:

```dart
await _refresh(includeEligiblePeople: false);
```

Keep `_openRoom` and the group-creation return path calling `_refresh()` so the
existing conservative eligible-people refresh behavior remains available after
navigation.

- [ ] **Step 6: Remove the duplicate continuous shell subscription**

In `main_shell.dart`:

- remove the `ChatRepository` import;
- remove `_chatRepository` and `_notificationBadgeChannel`;
- remove repository initialization, `_refreshChatBadge()`, and the
  `subscribeToNotificationChanges` block from `initState`;
- remove `_refreshChatBadge()` from application resume and navigation taps;
- remove channel unsubscription from `dispose`; and
- delete the `_refreshChatBadge()` method.

Keep this callback unchanged as the only badge update entry:

```dart
void _handleChatBadgeCountChanged(int count) {
  if (!mounted || _chatBadgeCount == count) return;
  setState(() => _chatBadgeCount = count);
}
```

Keep the existing `ChatPage` construction:

```dart
ChatPage(onBadgeCountChanged: _handleChatBadgeCountChanged),
```

After `ChatPage` has migrated, delete the temporary legacy
`subscribeToChatChanges` method from `chat_repository.dart`. At this point it
has no callers; the chat home and room use their purpose-specific methods.

- [ ] **Step 7: Format and run chat-home tests**

```powershell
dart format lib/src/features/chat/data/chat_repository.dart lib/src/features/chat/presentation/chat_page.dart lib/src/features/shell/presentation/main_shell.dart test/chat_realtime_lifecycle_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart
flutter test test/chat_realtime_lifecycle_test.dart test/chat_widgets_test.dart test/chat_repository_test.dart test/cyanzone_bottom_navigation_test.dart test/unread_badge_test.dart --no-pub --reporter expanded
```

Expected: PASS. The concurrency test proves both independent reads start before
the slower conversation read completes, and resume performs one ChatPage-owned
home refresh.

- [ ] **Step 8: Commit the chat-home ownership checkpoint**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/test/chat_realtime_lifecycle_test.dart apps/mobile/test/chat_repository_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): optimize chat home refresh ownership"
```

---

### Task 6: Complete the Phase 4B verification gate

**Files:**

- Verify: all Phase 4B production and test files
- Modify only if verification exposes a Phase 4B regression

- [ ] **Step 1: Run coordinator and lifecycle tests**

```powershell
flutter test test/chat_refresh_coordinator_test.dart test/chat_realtime_lifecycle_test.dart --no-pub --reporter expanded
```

Expected: all coordinator and lifecycle tests PASS.

- [ ] **Step 2: Run the complete focused chat regression group**

```powershell
flutter test test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart test/chat_repository_test.dart test/profile_message_action_test.dart test/app_confirmation_dialog_test.dart test/app_feedback_test.dart test/unread_badge_test.dart test/cyanzone_bottom_navigation_test.dart --no-pub --reporter expanded
```

Expected: all selected tests PASS with zero failures.

- [ ] **Step 3: Run complete Flutter analysis**

```powershell
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4: Verify formatting and repository scope**

Run from `apps/mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib/src/features/chat/application/chat_refresh_coordinator.dart lib/src/features/chat/data/chat_repository.dart lib/src/features/chat/presentation/chat_page.dart lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/shell/presentation/main_shell.dart test/chat_refresh_coordinator_test.dart test/chat_realtime_lifecycle_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart
```

Run from the repository root:

```powershell
git diff --check
git status --short --branch
```

Expected: formatting reports no changed files, Git reports no whitespace
errors, and the working tree is clean.

- [ ] **Step 5: Perform the short Android acceptance check**

On the available Android phone, verify:

1. Open Messages and receive or send several rapid messages; the conversation
   preview and badge update normally.
2. Open one room and confirm messages from that room appear without visible
   delay.
3. Confirm sending text and images still refreshes the room and scrolls to the
   latest content.
4. Confirm an unfollowed direct chat still blocks sending.
5. Open Activity, System, and New Followers; confirm new items and read states
   still update.
6. Background and resume CyanZone; confirm the chat badge and lists refresh.

Expected: no visible UI change, no duplicate rows, and no broken navigation or
interaction.

- [ ] **Step 6: Record any verification-only correction**

Do not create an empty commit. If a focused correction is required, first add
a failing regression assertion to the nearest Phase 4B test, apply only that
correction, repeat Steps 1-4, and commit:

```powershell
git add apps/mobile
git commit -m "fix(mobile): close chat refresh checkpoint gaps"
```

## Completion gate

Phase 4B is complete only when the coordinator tests, lifecycle contracts,
focused chat regressions, bottom-navigation badge tests, and Flutter analysis
all pass; formatting and `git diff --check` are clean; each channel and
coordinator has one disposal owner; and no known Android acceptance blocker
remains.

After this gate, proceed to Phase 5 for the separately scoped parent-child,
profile, and authentication presentation refactor.
