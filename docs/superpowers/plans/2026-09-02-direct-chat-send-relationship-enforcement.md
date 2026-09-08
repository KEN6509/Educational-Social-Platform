# Direct Chat Send Relationship Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep old direct-chat history visible while preventing new messages when neither participant follows the other.

**Architecture:** Supabase will expose the current conversation send permission and independently enforce it inside `send_chat_message`. The Flutter repository will hydrate conversation-list permission and call the permission RPC for chat rooms; `ChatRoomPage` will render a blocked state and react safely to stale permission errors.

**Tech Stack:** Flutter/Dart, Supabase Postgres/PostgREST RPC, PL/pgSQL, `flutter_test`.

---

### Task 1: Enforce current follows in Supabase

**Files:**
- Modify: `apps/mobile/test/chat_sql_migration_test.dart`
- Modify: `supabase/chat.sql`

- [ ] **Step 1: Write the failing SQL contract tests**

Add focused tests that isolate `can_send_chat_message` and `send_chat_message`:

```dart
test('chat SQL exposes current conversation send permission', () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();
  final start = sql.indexOf(
    'create or replace function public.can_send_chat_message',
  );
  final end = sql.indexOf(
    'create or replace function public.send_chat_message',
    start,
  );

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  final functionSql = sql.substring(start, end);
  expect(functionSql, contains("cm.status = 'active'"));
  expect(functionSql, contains("c.type = 'group'"));
  expect(
    functionSql,
    contains('public.chat_users_have_follow_relationship'),
  );
});

test('direct message send rechecks the current follow relationship', () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();
  final start = sql.indexOf(
    'create or replace function public.send_chat_message',
  );
  final end = sql.indexOf(
    'create or replace function public.mark_conversation_read',
    start,
  );

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  final functionSql = sql.substring(start, end);
  expect(functionSql, contains("v_conversation.type = 'direct'"));
  expect(functionSql, contains('public.can_send_chat_message'));
  expect(
    functionSql,
    contains("raise exception 'Follow relationship required'"),
  );
});
```

- [ ] **Step 2: Run the SQL test and verify RED**

Run:

```powershell
flutter test test/chat_sql_migration_test.dart
```

Expected: FAIL because `can_send_chat_message` and the direct-send guard do not exist.

- [ ] **Step 3: Add the permission RPC and direct-send guard**

Before `send_chat_message`, add a security-definer function shaped as follows:

```sql
create or replace function public.can_send_chat_message(
  p_conversation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_conversations c
    join public.chat_conversation_members cm
      on cm.conversation_id = c.id
     and cm.user_id = auth.uid()
     and cm.status = 'active'
    where c.id = p_conversation_id
      and (
        c.type = 'group'
        or exists (
          select 1
          from public.chat_conversation_members other_cm
          where other_cm.conversation_id = c.id
            and other_cm.user_id <> auth.uid()
            and other_cm.status = 'active'
            and public.chat_users_have_follow_relationship(
              auth.uid(),
              other_cm.user_id
            )
        )
      )
  );
$$;
```

After the existing active-membership check in `send_chat_message`, add:

```sql
if v_conversation.type = 'direct'
  and not public.can_send_chat_message(p_conversation_id)
then
  raise exception 'Follow relationship required';
end if;
```

Add the matching revoke/grant statements near the other RPC permissions:

```sql
revoke execute on function public.can_send_chat_message(uuid)
  from public, anon;
grant execute on function public.can_send_chat_message(uuid)
  to authenticated;
```

- [ ] **Step 4: Run the SQL test and verify GREEN**

Run `flutter test test/chat_sql_migration_test.dart`.

Expected: PASS.

- [ ] **Step 5: Commit backend enforcement**

```powershell
git add -- supabase/chat.sql apps/mobile/test/chat_sql_migration_test.dart
git commit -m "fix: enforce follows when sending direct messages"
```

### Task 2: Carry direct-chat eligibility into the Messages page

**Files:**
- Modify: `apps/mobile/test/chat_models_test.dart`
- Modify: `apps/mobile/test/chat_repository_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_models.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`

- [ ] **Step 1: Write failing model, repository, and tile tests**

Add assertions for a default-allowed legacy map and an explicit blocked map:

```dart
expect(ChatConversation.fromMap({'id': 'c', 'type': 'direct'}).canSendMessages,
    isTrue);
expect(ChatConversation.fromMap({
  'id': 'c',
  'type': 'direct',
  'can_send_messages': false,
}).canSendMessages, isFalse);
```

Extend the stable-RPC test:

```dart
expect(ChatRepository.canSendChatMessageRpc, 'can_send_chat_message');
```

Add a `ConversationTile` widget test using an empty, direct conversation with `canSendMessages: false` and assert:

```dart
expect(find.text('Follow this user to continue chatting.'), findsOneWidget);
expect(find.text('Start chatting'), findsNothing);
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
flutter test test/chat_models_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart
```

Expected: FAIL because the model flag and RPC constant are absent and the tile still uses `Start chatting`.

- [ ] **Step 3: Add the model flag and repository permission API**

Add `canSendMessages` to `ChatConversation`, its constructor, `copyWith`, and `fromMap`. Missing legacy values default to `true`:

```dart
final bool canSendMessages;

canSendMessages: map.containsKey('can_send_messages') ||
        map.containsKey('canSendMessages')
    ? _boolValue(map['can_send_messages'] ?? map['canSendMessages'])
    : true,
```

Add the RPC constant and method:

```dart
static const canSendChatMessageRpc = 'can_send_chat_message';

Future<bool> canSendMessage(String conversationId) async {
  final response = await _client.rpc<bool>(
    canSendChatMessageRpc,
    params: {conversationIdParam: conversationId},
  );
  return response;
}
```

During `_hydrateConversations`, collect direct-chat other-user IDs and query `public.follows` in both directions with the authenticated user. Add `can_send_messages` to each enriched direct-conversation map based on membership in the union of those relationship IDs. Groups remain allowed.

- [ ] **Step 4: Change the Messages-page empty preview**

Change the direct empty fallback in `ConversationTile` to:

```dart
fallback: conversation.isRequest
    ? 'Message request'
    : !conversation.isGroup && !conversation.canSendMessages
        ? 'Follow this user to continue chatting.'
        : 'Start chatting',
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run `flutter test test/chat_models_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart`.

Expected: PASS.

- [ ] **Step 6: Commit Messages-page permission state**

```powershell
git add -- apps/mobile/lib/src/features/chat/data/chat_models.dart apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_models_test.dart apps/mobile/test/chat_repository_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix: show blocked direct chats in messages"
```

### Task 3: Block the direct-chat composer safely

**Files:**
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`

- [ ] **Step 1: Write failing chat-room widget tests**

Add an injectable permission callback:

```dart
typedef SendPermissionLoader = Future<bool> Function(String conversationId);
```

Tests will construct direct conversations with `loadSendPermission: (_) async => false` and verify the follow-required notice appears, `TextField`, image, and send icons are absent, and an existing `ChatMessage` remains visible. A separate group test verifies its composer remains present.

Add a stale-state test where permission initially returns true but `sendMessage` throws `Exception('Follow relationship required')`. Enter `draft`, tap Send, and assert:

```dart
expect(find.text('draft'), findsOneWidget);
expect(find.text('Follow this user to continue chatting.'), findsWidgets);
expect(find.byIcon(Icons.send_rounded), findsNothing);
```

- [ ] **Step 2: Run the chat widget test and verify RED**

Run `flutter test test/chat_widgets_test.dart`.

Expected: FAIL because `loadSendPermission` and the blocked UI do not exist.

- [ ] **Step 3: Implement permission loading and lifecycle refresh**

Add the optional widget dependency:

```dart
final SendPermissionLoader? loadSendPermission;
```

For direct chats, load `(widget.loadSendPermission ?? _repo.canSendMessage)(_conversation.id)` in `initState`; group chats remain allowed. Refresh the permission from `didChangeAppLifecycleState` when the state is `AppLifecycleState.resumed`.

Use a nullable state while a direct permission is loading. Do not expose the composer until permission is confirmed. Render a compact progress indicator during the initial check and `Follow this user to continue chatting.` when denied.

- [ ] **Step 4: Enforce blocked UI and stale-send handling**

Replace the composer with a keyed follow-required notice when permission is false. Change the empty direct-room prompt to the same notice when blocked. Add guards to `_send` and `_sendImage`.

In `_send` error handling, detect `Follow relationship required`, preserve the controller text, set permission to false, and map the snackbar text to `Follow this user to continue chatting.` Existing error mappings remain unchanged.

Update existing direct `ChatRoomPage` tests to inject `loadSendPermission: (_) async => true`; group tests need no permission callback.

- [ ] **Step 5: Run the chat widget test and verify GREEN**

Run `flutter test test/chat_widgets_test.dart`.

Expected: PASS.

- [ ] **Step 6: Commit the blocked composer**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix: disable direct chat after unfollow"
```

### Task 4: Document and verify the focused fix

**Files:**
- Modify: `Project_Overview.md`
- Modify: `supabase/README.md`
- Modify: `docs/superpowers/specs/2026-09-02-direct-chat-send-relationship-enforcement-design.md`

- [ ] **Step 1: Update documentation**

Record that direct-chat history remains visible after unfollow, but all new direct-message sends require a current follow row in either direction. State that the latest complete `supabase/chat.sql` must be rerun to install `can_send_chat_message` and the updated `send_chat_message`; existing rows are preserved.

- [ ] **Step 2: Run focused verification only**

Run:

```powershell
dart format lib/src/features/chat/data/chat_models.dart lib/src/features/chat/data/chat_repository.dart lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_widgets.dart test/chat_models_test.dart test/chat_repository_test.dart test/chat_sql_migration_test.dart test/chat_widgets_test.dart
flutter test test/chat_sql_migration_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_models_test.dart
flutter analyze lib/src/features/chat test/chat_sql_migration_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_models_test.dart
```

Expected: formatting succeeds, all focused tests pass, and focused analysis reports no issues.

- [ ] **Step 3: Check the diff and commit documentation**

```powershell
git diff --check
git status --short
git add -- Project_Overview.md supabase/README.md docs/superpowers/specs/2026-09-02-direct-chat-send-relationship-enforcement-design.md
git commit -m "docs: record direct chat send enforcement"
```
