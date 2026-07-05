# Notification Read State and Badge Counts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix notification read-state, Activity unavailable-post behavior, badge counts, per-chat unread counts, and add the Unread messages filter.

**Architecture:** Keep the work in the existing chat repository/UI boundaries. Add pure helper methods for badge math and filtering so widget tests can verify behavior without Supabase, then wire those helpers into `ChatPage`, `NotificationSectionsPage`, and `MainShell`. Use existing Supabase tables/functions; add only lightweight repository methods and SQL/read-state tests.

**Tech Stack:** Flutter, Dart, Supabase/PostgREST, PL/pgSQL, `flutter_test`.

---

## Files and responsibilities

- `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
  - Add read-state methods, bottom badge helper, unread conversation calculation helper, and unavailable-post error type.
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
  - Mark section notifications read when leaving.
  - Show unavailable-post snackbar when related post cannot be viewed.
- `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
  - Refresh notification counts after returning from notification pages.
  - Add `Unread` messages filter and empty state action.
  - Update chip styling.
- `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
  - Use the new bottom-bar chat badge count method.
- `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
  - Keep per-conversation badge display; no structural change unless tests reveal a small styling issue.
- `apps/mobile/test/chat_repository_test.dart`
  - Cover pure helper methods and source-level read-state methods.
- `apps/mobile/test/chat_widgets_test.dart`
  - Cover notification read callback, unavailable-post snackbar, filter order, unread empty state, and View all chats action.
- `apps/mobile/test/chat_sql_migration_test.dart`
  - Strengthen SQL coverage for Activity triggers/migration notes.
- `supabase/README.md`
  - Add a short note that updated `supabase/chat.sql` must be applied to live Supabase for comment/reply/mention notifications.

---

### Task 1: Repository read-state and badge helpers

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Test: `apps/mobile/test/chat_repository_test.dart`

- [ ] **Step 1: Write failing helper tests**

Add these tests inside `group('ChatRepository', () { ... })` in `apps/mobile/test/chat_repository_test.dart`.

```dart
test('bottom badge counts notification sections as sources plus unread chats', () {
  final counts = {
    NotificationSection.activity: 5,
    NotificationSection.system: 2,
    NotificationSection.followers: 0,
    NotificationSection.chat: 9,
  };
  final conversations = [
    ChatConversation.fromMap({
      'id': 'c1',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 3,
    }),
    ChatConversation.fromMap({
      'id': 'c2',
      'type': 'group',
      'request_status': 'accepted',
      'unread_count': 0,
    }),
    ChatConversation.fromMap({
      'id': 'c3',
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 1,
    }),
  ];

  expect(
    ChatRepository.bottomChatBadgeCount(
      notificationCounts: counts,
      conversations: conversations,
    ),
    4,
  );
});

test('source contains section read marker and unread conversation calculation', () {
  final source = File('lib/src/features/chat/data/chat_repository.dart')
      .readAsStringSync();

  expect(source, contains('markNotificationsReadForSection'));
  expect(source, contains('mark_notifications_read_for_section'));
  expect(source, contains('calculateUnreadConversationCount'));
  expect(source, contains('last_read_at'));
  expect(source, contains('cleared_at'));
});
```

- [ ] **Step 2: Run repository tests and verify they fail**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart
```

Expected: fails because `bottomChatBadgeCount`, `markNotificationsReadForSection`, and `calculateUnreadConversationCount` do not exist.

- [ ] **Step 3: Add unavailable-post error and badge helper**

In `apps/mobile/lib/src/features/chat/data/chat_repository.dart`, below `NotificationActivityFilter`, add:

```dart
class ChatNotificationPostUnavailableException implements Exception {
  const ChatNotificationPostUnavailableException();

  @override
  String toString() => 'ChatNotificationPostUnavailableException';
}
```

Inside `ChatRepository`, add:

```dart
  static int bottomChatBadgeCount({
    required Map<NotificationSection, int> notificationCounts,
    required List<ChatConversation> conversations,
  }) {
    final notificationSources = [
      NotificationSection.activity,
      NotificationSection.system,
      NotificationSection.followers,
    ].where((section) => (notificationCounts[section] ?? 0) > 0).length;
    final unreadConversations =
        conversations.where((conversation) => conversation.unreadCount > 0).length;
    return notificationSources + unreadConversations;
  }
```

- [ ] **Step 4: Add read marker method**

Inside `ChatRepository`, add:

```dart
  Future<void> markNotificationsReadForSection(
    NotificationSection section,
  ) async {
    var query = _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null);

    switch (section) {
      case NotificationSection.activity:
        query = query.not('type', 'in', '(system,new_follower,chat_message)');
      case NotificationSection.system:
        query = query.eq('type', 'system');
      case NotificationSection.followers:
        query = query.eq('type', 'new_follower');
      case NotificationSection.chat:
        return;
    }

    await query;
  }
```

- [ ] **Step 5: Add unread conversation helper**

Inside `ChatRepository`, add:

```dart
  static int calculateUnreadConversationCount({
    required List<Map<String, dynamic>> messages,
    required String currentUserId,
    DateTime? lastReadAt,
    DateTime? clearedAt,
  }) {
    return messages.where((message) {
      final senderId = _string(message['sender_id'] ?? message['senderId']);
      if (senderId.isEmpty || senderId == currentUserId) return false;
      if (message['deleted_at'] != null || message['deletedAt'] != null) {
        return false;
      }
      final createdAt = _dateTimeFromObject(
        message['created_at'] ?? message['createdAt'],
      );
      if (createdAt == null) return false;
      if (lastReadAt != null && !createdAt.isAfter(lastReadAt)) return false;
      if (clearedAt != null && !createdAt.isAfter(clearedAt)) return false;
      return true;
    }).length;
  }
```

Add private date helper near existing private helpers:

```dart
DateTime? _dateTimeFromObject(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.isUtc ? value.toLocal() : value;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}
```

- [ ] **Step 6: Use helper in conversation hydration**

In `_hydrateConversations`, before building `enriched`, derive current member and messages:

```dart
      final currentMember = (membersByConversation[conversationId] ?? const [])
          .where((member) => _string(member['user_id']) == currentUserId)
          .firstOrNull;
      final lastReadAt =
          _dateTimeFromObject(currentMember?['last_read_at']);
      final clearedAt = _dateTimeFromObject(currentMember?['cleared_at']);
      final conversationMessages =
          lastMessagesByConversation[conversationId] == null
              ? const <Map<String, dynamic>>[]
              : [lastMessagesByConversation[conversationId]!];
      final unreadCount = calculateUnreadConversationCount(
        messages: conversationMessages,
        currentUserId: currentUserId,
        lastReadAt: lastReadAt,
        clearedAt: clearedAt,
      );
```

Replace:

```dart
..['unread_count'] = 0
```

with:

```dart
..['unread_count'] = unreadCount
```

This gives a safe first implementation based on the currently fetched latest message. If a conversation has many unread messages, a later SQL/RPC optimization can count all rows, but this pass enables the row/bottom badge source behavior without a heavy query.

- [ ] **Step 7: Run repository tests and verify they pass**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart
```

Expected: all repository tests pass.

- [ ] **Step 8: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/test/chat_repository_test.dart
git commit -m "feat: add notification badge helpers"
```

---

### Task 2: Notification page read-state and unavailable post handling

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing widget tests**

Add these tests to `apps/mobile/test/chat_widgets_test.dart`.

```dart
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
    find.text("This post can't be viewed. It may be deleted or not approved yet."),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "NotificationSectionsPage marks section read|Activity row shows missing post"
```

Expected: fails because injection hooks/read marking are not implemented.

- [ ] **Step 3: Add injection typedefs and widget parameters**

In `notification_sections_page.dart`, add:

```dart
typedef NotificationSectionReadMarker = Future<void> Function(
  NotificationSection section,
);

typedef ActivityPostOpener = Future<void> Function(
  ChatNotification notification,
);
```

Add optional fields to `NotificationSectionsPage`:

```dart
this.markSectionRead,
this.openActivityPost,
```

and:

```dart
final NotificationSectionReadMarker? markSectionRead;
final ActivityPostOpener? openActivityPost;
```

- [ ] **Step 4: Mark section read on back/dispose**

Add state field:

```dart
bool _markedRead = false;
```

Add method:

```dart
  Future<void> _markCurrentSectionRead() async {
    if (_markedRead || _section == NotificationSection.chat) return;
    _markedRead = true;
    final marker = widget.markSectionRead;
    if (marker != null) {
      await marker(_section);
      return;
    }
    await _repo.markNotificationsReadForSection(_section);
  }
```

Wrap the scaffold in `PopScope`:

```dart
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        _markCurrentSectionRead();
      },
      child: ChatNoSplash(
        child: Scaffold(
          ...
        ),
      ),
    );
```

Change leading button:

```dart
            onPressed: () async {
              await _markCurrentSectionRead();
              if (context.mounted) Navigator.pop(context, true);
            },
```

- [ ] **Step 5: Use injected Activity opener and snackbar**

Change `_openActivityPost`:

```dart
  Future<void> _openActivityPost(ChatNotification notification) async {
    try {
      final injected = widget.openActivityPost;
      if (injected != null) {
        await injected(notification);
        return;
      }
      final postId = notification.postId;
      if (postId == null) throw const ChatNotificationPostUnavailableException();
      final post = await _repo.fetchPostForNotification(postId);
      if (post.moderationStatus != 'approved') {
        throw const ChatNotificationPostUnavailableException();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
      );
    } on ChatNotificationPostUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This post can't be viewed. It may be deleted or not approved yet.",
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }
```

- [ ] **Step 6: Run focused tests and verify they pass**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "NotificationSectionsPage marks section read|Activity row shows missing post"
```

Expected: focused tests pass.

- [ ] **Step 7: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: mark notification sections read"
```

---

### Task 3: Chat page refresh, Unread filter, and chip styling

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing ChatPage tests**

Add these widget tests to `apps/mobile/test/chat_widgets_test.dart`.

```dart
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
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "message filters include unread|Unread filter empty state"
```

Expected: fails because `_MessageFilter.unread` and empty action do not exist.

- [ ] **Step 3: Add unread filter enum and filtering**

In `chat_page.dart`, change:

```dart
enum _MessageFilter { all, groups, requests }
```

to:

```dart
enum _MessageFilter { all, unread, groups, requests }
```

In visible conversations switch, add:

```dart
_MessageFilter.unread => conversations
    .where((conversation) => conversation.unreadCount > 0)
    .toList(),
```

- [ ] **Step 4: Add Unread chip in filter bar**

In `_MessageFilterBar`, insert between All and Groups:

```dart
const SizedBox(width: 8),
_MessageFilterChip(
  label: 'Unread',
  selected: selected == _MessageFilter.unread,
  onTap: () => onChanged(_MessageFilter.unread),
),
```

- [ ] **Step 5: Update filter chip styling**

In `_MessageFilterChip`, set default style:

```dart
        decoration: BoxDecoration(
          color: selected ? chatNavy : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? chatNavy : const Color(0xFFE2E8F0),
          ),
        ),
```

Set text style:

```dart
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
```

- [ ] **Step 6: Add unread empty state action**

Where empty conversations are handled, before the generic empty state add:

```dart
if (visibleConversations.isEmpty && _messageFilter == _MessageFilter.unread) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ChatNoResultsState(
      title: 'No chats in Unread',
      subtitleWidget: GestureDetector(
        onTap: () => setState(() => _messageFilter = _MessageFilter.all),
        child: const Text(
          'View all chats',
          style: TextStyle(
            color: chatNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      icon: Icons.mark_chat_read_outlined,
    ),
  );
}
```

If `ChatNoResultsState` does not have `subtitleWidget`, add optional `subtitleWidget` support in `chat_widgets.dart`:

```dart
final Widget? subtitleWidget;
```

and render `subtitleWidget ?? Text(subtitle, ...)`.

- [ ] **Step 7: Refresh counts after returning from notification pages**

In `_openNotifications`, change:

```dart
await Navigator.of(context).push(...)
```

to:

```dart
await Navigator.of(context).push(...)
if (!mounted) return;
setState(() => _future = _load());
```

- [ ] **Step 8: Run focused tests and verify they pass**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_widgets_test.dart --name "message filters include unread|Unread filter empty state"
```

Expected: focused tests pass.

- [ ] **Step 9: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: add unread chat filter"
```

---

### Task 4: Bottom navigation chat badge source count

**Files:**
- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
- Test: `apps/mobile/test/chat_repository_test.dart`

- [ ] **Step 1: Write failing source-level test**

Add this to `apps/mobile/test/chat_repository_test.dart`:

```dart
test('main shell uses total chat badge count instead of chat message only count',
    () {
  final source =
      File('lib/src/features/shell/presentation/main_shell.dart').readAsStringSync();

  expect(source, contains('fetchUnreadChatTabBadgeCount'));
  expect(source, isNot(contains('fetchUnreadChatCount();')));
});
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart --name "main shell uses total chat badge"
```

Expected: fails because MainShell still calls `fetchUnreadChatCount()`.

- [ ] **Step 3: Add repository method**

In `ChatRepository`, add:

```dart
  Future<int> fetchUnreadChatTabBadgeCount() async {
    final conversations = await fetchConversations();
    final counts = await fetchUnreadNotificationCounts();
    return bottomChatBadgeCount(
      notificationCounts: counts,
      conversations: conversations,
    );
  }
```

- [ ] **Step 4: Use new method in MainShell**

In `main_shell.dart`, replace:

```dart
final count = await _chatRepository.fetchUnreadChatCount();
```

with:

```dart
final count = await _chatRepository.fetchUnreadChatTabBadgeCount();
```

- [ ] **Step 5: Run focused test and verify it passes**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart --name "main shell uses total chat badge"
```

Expected: focused test passes.

- [ ] **Step 6: Commit**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/test/chat_repository_test.dart
git commit -m "feat: count chat tab notification sources"
```

---

### Task 5: Supabase migration note and SQL coverage

**Files:**
- Modify: `supabase/README.md`
- Modify: `apps/mobile/test/chat_sql_migration_test.dart`

- [ ] **Step 1: Write failing migration-note test**

Add this to `apps/mobile/test/chat_sql_migration_test.dart`:

```dart
test('Supabase README documents applying chat SQL for activity triggers', () {
  final readme = File('../../supabase/README.md').readAsStringSync();

  expect(readme, contains('comment_reply'));
  expect(readme, contains('comment_like'));
  expect(readme, contains('supabase/chat.sql'));
});
```

- [ ] **Step 2: Run focused test and verify it fails**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_sql_migration_test.dart --name "README documents applying chat SQL"
```

Expected: fails if the README does not document the live DB trigger requirement.

- [ ] **Step 3: Add README note**

In `supabase/README.md`, add:

```markdown
## Chat activity notification triggers

Apply `supabase/chat.sql` to the live Supabase database after pulling chat notification changes. The Activity page depends on notification trigger types including `comment_reply`, `comment_like`, and `mention`. Existing notifications are not backfilled automatically; create a new comment, reply, mention, or comment like after applying the SQL to verify the live trigger path.
```

- [ ] **Step 4: Run focused test and verify it passes**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_sql_migration_test.dart --name "README documents applying chat SQL"
```

Expected: focused test passes.

- [ ] **Step 5: Commit**

```powershell
git add supabase/README.md apps/mobile/test/chat_sql_migration_test.dart
git commit -m "docs: document chat activity trigger migration"
```

---

### Task 6: Full verification

**Files:**
- All changed Dart and documentation files

- [ ] **Step 1: Run focused tests**

Run:

```powershell
cd apps/mobile
flutter test --no-pub test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_sql_migration_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 2: Format changed Dart files**

Run:

```powershell
cd apps/mobile
dart format lib/src/features/chat/data/chat_repository.dart lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/chat/presentation/chat_page.dart lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/shell/presentation/main_shell.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_sql_migration_test.dart
```

Expected: formatter completes without errors.

- [ ] **Step 3: Analyze**

Run:

```powershell
cd apps/mobile
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4: Run full tests**

Run:

```powershell
cd apps/mobile
flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 5: Commit final formatting if needed**

If formatting changed files:

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/test/chat_repository_test.dart apps/mobile/test/chat_widgets_test.dart apps/mobile/test/chat_sql_migration_test.dart
git commit -m "polish: verify notification badge updates"
```

If there are no changes after verification, do not create an empty commit.

---

## Self-review notes

- Spec coverage:
  - Activity unavailable post snackbar: Task 2.
  - Mark section notifications read on exit: Task 2.
  - Refresh chat page counts after returning: Task 3.
  - Shortcut badges exact counts: existing `ChatPage` count display remains and Task 2/3 makes read-state correct.
  - Conversation row unread count: Task 1.
  - Bottom-bar source count: Task 1 and Task 4.
  - Unread filter and chip styling: Task 3.
  - Supabase live migration note: Task 5.
- Placeholder scan:
  - No unfinished placeholders remain.
- Type consistency:
  - `ChatNotificationPostUnavailableException`, `bottomChatBadgeCount`, `calculateUnreadConversationCount`, `markNotificationsReadForSection`, and `fetchUnreadChatTabBadgeCount` are introduced before use.
