# Hidden Message Requests and Chat Conformance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide message requests from every active mobile entry point, require a follow relationship before profile messaging, and limit group-member eligibility to Followers/Following while preserving dormant request data and code.

**Architecture:** Keep the existing request-capable Supabase schema and RPCs as dormant infrastructure. Add a relationship-gated RPC for active Flutter flows, simplify the chat-home state to normal conversations only, and make the existing follower/following query the sole source of group candidates at both client and server boundaries.

**Tech Stack:** Flutter/Dart, `supabase_flutter`, PostgreSQL/Supabase RPC and RLS, `flutter_test`, Markdown documentation.

---

## File Structure

- Modify `supabase/chat.sql`: add the relationship-gated direct-chat RPC and narrow group-member authorization.
- Modify `apps/mobile/lib/src/features/chat/data/chat_repository.dart`: expose the gated RPC and remove accepted-chat member expansion from group suggestions.
- Modify `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`: stop loading/rendering message requests and use the gated direct-chat action.
- Modify `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`: use the gated action from New Followers.
- Modify `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`: show follow-only group eligibility feedback.
- Create `apps/mobile/lib/src/features/profile/presentation/profile_message_action.dart`: coordinate profile Message navigation and friendly relationship errors through injectable actions.
- Modify `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`: delegate its Message button to the focused action helper.
- Modify `apps/mobile/test/chat_sql_migration_test.dart`: verify dormant request SQL and active follow-only authorization.
- Modify `apps/mobile/test/chat_repository_test.dart`: verify RPC names and accepted-chat exclusion.
- Modify `apps/mobile/test/chat_widgets_test.dart`: verify the Requests UI and loader are absent.
- Create `apps/mobile/test/profile_message_action_test.dart`: verify the profile success and follow-first outcomes.
- Modify `Project_Overview.md`, `apps/mobile/README.md`, and `supabase/README.md`: document the new active/dormant boundaries and SQL reapplication requirement.

### Task 1: Define the Server-Authoritative Relationship Boundary

**Files:**
- Modify: `apps/mobile/test/chat_sql_migration_test.dart`
- Modify: `supabase/chat.sql`

- [ ] **Step 1: Write failing SQL contract tests**

Add tests that isolate the relevant function bodies and require:

```dart
test('active direct chat requires a follow relationship', () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();
  final start = sql.indexOf(
    'create or replace function public.open_direct_conversation',
  );
  final end = sql.indexOf(
    'create or replace function public.create_group_conversation',
    start,
  );

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  final functionSql = sql.substring(start, end);
  expect(functionSql, contains('public.chat_users_have_follow_relationship'));
  expect(functionSql, contains("raise exception 'Follow relationship required'"));
  expect(functionSql, contains('public.create_direct_conversation'));
  expect(functionSql, contains("set request_status = 'accepted'"));
  expect(functionSql, contains("set status = 'active'"));
});

test('group member eligibility uses follows only', () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();
  final start = sql.indexOf(
    'create or replace function public.chat_can_add_group_member',
  );
  final end = sql.indexOf(
    'create or replace function public.chat_is_conversation_member',
    start,
  );

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  final functionSql = sql.substring(start, end);
  expect(functionSql, contains('public.chat_users_have_follow_relationship'));
  expect(functionSql, isNot(contains('chat_conversations')));
  expect(functionSql, isNot(contains('parent_child_links')));
});

test('message request SQL remains available as dormant infrastructure', () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();
  expect(sql, contains('create or replace function public.create_direct_conversation'));
  expect(sql, contains('create or replace function public.accept_message_request'));
  expect(sql, contains('Pending message requests are limited to 3 messages'));
});
```

- [ ] **Step 2: Run the SQL contract tests and verify RED**

Run:

```powershell
cd apps/mobile
flutter test test/chat_sql_migration_test.dart
```

Expected: FAIL because `open_direct_conversation` and the follow-only helper do not exist and group eligibility still checks accepted direct chats.

- [ ] **Step 3: Add follow-only SQL and the gated direct-chat RPC**

Add a stable helper:

```sql
create or replace function public.chat_users_have_follow_relationship(left_user uuid, right_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select left_user is not null
    and right_user is not null
    and left_user <> right_user
    and exists (
      select 1
      from public.follows f
      where (f.follower_id = left_user and f.following_id = right_user)
         or (f.follower_id = right_user and f.following_id = left_user)
    );
$$;
```

Replace `chat_can_add_group_member` with a direct call to this helper. Add `open_direct_conversation(target_user_id uuid)` after the existing request-capable creator. It must validate the follow relationship, call `create_direct_conversation`, and promote an existing pending pair after a relationship is established:

```sql
create or replace function public.open_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_conversation_id uuid;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if target_user_id is null or target_user_id = v_current_user then
    raise exception 'Target user is invalid';
  end if;

  if not public.chat_users_have_follow_relationship(
    v_current_user,
    target_user_id
  ) then
    raise exception 'Follow relationship required';
  end if;

  v_conversation_id := public.create_direct_conversation(target_user_id);

  update public.chat_conversations c
  set request_status = 'accepted',
      updated_at = now()
  where c.id = v_conversation_id
    and c.type = 'direct'
    and c.request_status = 'pending';

  update public.chat_conversation_members cm
  set status = 'active',
      joined_at = coalesce(cm.joined_at, now())
  where cm.conversation_id = v_conversation_id
    and cm.status = 'pending';

  return v_conversation_id;
end;
$$;
```

Revoke public/anonymous access and grant authenticated execution for the new RPC. Keep all request functions and columns unchanged. Update group rejection text to `Cannot add group member without a follow relationship`.

- [ ] **Step 4: Run the SQL contract tests and verify GREEN**

Run:

```powershell
cd apps/mobile
flutter test test/chat_sql_migration_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the SQL boundary**

```powershell
git add -- supabase/chat.sql apps/mobile/test/chat_sql_migration_test.dart
git commit -m "feat: enforce relationship-gated chat access"
```

### Task 2: Route Active Flutter Flows Through the Gated RPC

**Files:**
- Modify: `apps/mobile/test/chat_repository_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing repository contract tests**

Require the active RPC and ensure the accepted-chat expansion is absent:

```dart
test('exposes the relationship-gated direct chat RPC', () {
  expect(
    ChatRepository.openDirectConversationRpc,
    'open_direct_conversation',
  );
});

test('group suggestions come only from follow rows', () {
  final source = File('lib/src/features/chat/data/chat_repository.dart')
      .readAsStringSync();
  final start = source.indexOf(
    'Future<List<ChatParticipant>> fetchSuggestedGroupMembers',
  );
  final end = source.indexOf('RealtimeChannel subscribeToChatChanges', start);
  final methodSource = source.substring(start, end);

  expect(methodSource, contains(".from('follows')"));
  expect(methodSource, isNot(contains('acceptedDirectRows')));
  expect(methodSource, isNot(contains(".from('chat_conversations')")));
});

test('group member errors use follow-only copy', () {
  final source = File(
    'lib/src/features/chat/presentation/create_group_chat_page.dart',
  ).readAsStringSync();
  expect(
    source,
    contains('Only followers or people you follow can be added.'),
  );
  expect(source, isNot(contains('accepted recent chats')));
});
```

- [ ] **Step 2: Run repository tests and verify RED**

Run:

```powershell
cd apps/mobile
flutter test test/chat_repository_test.dart
```

Expected: FAIL because the gated RPC constant is absent and group suggestions still add accepted-chat members.

- [ ] **Step 3: Add the repository method and simplify suggestions**

Add:

```dart
static const openDirectConversationRpc = 'open_direct_conversation';

Future<String> openDirectConversation(String targetUserId) async {
  final response = await _client.rpc<String>(
    openDirectConversationRpc,
    params: {'target_user_id': targetUserId},
  );
  return _stringIdFromRpc(response);
}
```

Retain `createDirectConversation` as dormant request infrastructure. Remove the accepted-direct conversation and member queries from `fetchSuggestedGroupMembers`; return profiles for the follower/following ID union immediately.

Switch the active calls in `chat_page.dart` and `notification_sections_page.dart` from `createDirectConversation` to `openDirectConversation`. Map `Follow relationship required` to `Follow this user before sending a message.` where a stale New Followers notification could encounter it.

Change the group creation relationship error to `Only followers or people you follow can be added.` and keep matching the server's `Cannot add group member` error.

- [ ] **Step 4: Run repository and chat widget tests and verify GREEN**

Run:

```powershell
cd apps/mobile
flutter test test/chat_repository_test.dart test/chat_widgets_test.dart
```

Expected: PASS before the separate chat-home removal tests are introduced.

- [ ] **Step 5: Commit active routing and group suggestions**

```powershell
git add -- apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart apps/mobile/test/chat_repository_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: gate active direct chat entry"
```

### Task 3: Hide Message Requests From the Chat Home

**Files:**
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`

- [ ] **Step 1: Replace request UI tests with failing hidden-feature tests**

Update ChatPage test setup to omit `loadRequests`. Replace the Requests ordering/count/empty-state assertions with:

```dart
testWidgets('ChatPage exposes only All, Unread, and Groups filters',
    (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatPage(
        loadConversations: () async => const [],
        loadCounts: () async => const {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('All'), findsOneWidget);
  expect(find.text('Unread'), findsOneWidget);
  expect(find.text('Groups'), findsOneWidget);
  expect(find.text('Requests'), findsNothing);
  expect(find.text('No recent message requests'), findsNothing);
});
```

Add a source contract that rejects active request loading:

```dart
test('ChatPage does not load or cache message requests', () {
  final source = File('lib/src/features/chat/presentation/chat_page.dart')
      .readAsStringSync();
  expect(source, isNot(contains('loadRequests')));
  expect(source, isNot(contains('fetchMessageRequests')));
  expect(source, isNot(contains('_requestsCacheKey')));
  expect(source, isNot(contains('_cachedRequests')));
});
```

- [ ] **Step 2: Run the focused widget tests and verify RED**

Run:

```powershell
cd apps/mobile
flutter test test/chat_widgets_test.dart
```

Expected: FAIL because the Requests filter, count, empty state, loader, and cache are still active.

- [ ] **Step 3: Remove the active request state and UI**

In `chat_page.dart`:

- change `_MessageFilter` to `{ all, unread, groups }`;
- remove `loadRequests` from `ChatPage` and `_shouldUseInjectedData`;
- remove the request cache key and static list;
- stop fetching/restoring/serializing request conversations;
- remove `requests` from `_ChatHomeState`;
- remove 30-day request filtering and request unread calculations;
- remove the Requests switch branch, empty state, filter-bar parameter, count, and chip.

Do not delete `ChatRequestStatus`, `fetchMessageRequests`, request RPC constants, or the existing pending-message error because those remain dormant for possible restoration.

- [ ] **Step 4: Format and run the focused widget tests**

Run:

```powershell
dart format lib/src/features/chat/presentation/chat_page.dart test/chat_widgets_test.dart
flutter test test/chat_widgets_test.dart
```

Expected: PASS with no Requests UI.

- [ ] **Step 5: Commit the hidden chat home**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: hide message requests from chat home"
```

### Task 4: Add the Profile Follow-First Message Action

**Files:**
- Create: `apps/mobile/test/profile_message_action_test.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/profile_message_action.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`

- [ ] **Step 1: Write failing profile action tests**

Create widget tests around an injectable action helper. The blocked test must throw the server error, tap Message, and assert the exact snackbar plus no navigation:

```dart
const testProfile = UserProfile(
  id: 'other-user',
  email: 'other@example.com',
  name: 'Other User',
);

testWidgets('profile Message requires a follow relationship', (tester) async {
  var navigated = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
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
  );

  await tester.tap(find.text('Message'));
  await tester.pump();

  expect(find.text('Follow this user before sending a message.'), findsOneWidget);
  expect(navigated, isFalse);
});
```

The success test returns a conversation ID and asserts the navigator receives a direct, accepted `ChatConversation` for the selected profile.

- [ ] **Step 2: Run the profile action tests and verify RED**

Run:

```powershell
cd apps/mobile
flutter test test/profile_message_action_test.dart
```

Expected: FAIL because `profile_message_action.dart` and `openProfileMessage` do not exist.

- [ ] **Step 3: Implement the focused profile message coordinator**

Create `profile_message_action.dart` with:

```dart
typedef ProfileConversationOpener = Future<String> Function(String userId);
typedef ProfileConversationNavigator = Future<void> Function(
  BuildContext context,
  ChatConversation conversation,
);

Future<void> openProfileMessage({
  required BuildContext context,
  required UserProfile profile,
  ProfileConversationOpener? openConversation,
  ProfileConversationNavigator? navigate,
}) async {
  try {
    final action = openConversation ??
        ChatRepository(Supabase.instance.client).openDirectConversation;
    final conversationId = await action(profile.id);
    if (!context.mounted) return;
    final conversation = ChatConversation.fromMap({
      'id': conversationId,
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_id': profile.id,
      'other_user_name': profile.name,
      'other_user_avatar_url': profile.avatarUrl,
    });
    if (navigate != null) {
      await navigate(context, conversation);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(conversation: conversation),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    final text = error.toString().contains('Follow relationship required')
        ? 'Follow this user before sending a message.'
        : friendlyErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
```

Replace the inline profile Message callback with `openProfileMessage(context: context, profile: profile)`. Remove chat-specific imports from `profile_page.dart` and import the focused helper instead.

- [ ] **Step 4: Format and run profile/repository tests**

Run:

```powershell
dart format lib/src/features/profile/presentation/profile_message_action.dart lib/src/features/profile/presentation/profile_page.dart test/profile_message_action_test.dart
flutter test test/profile_message_action_test.dart test/chat_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the profile message gate**

```powershell
git add -- apps/mobile/lib/src/features/profile/presentation/profile_message_action.dart apps/mobile/lib/src/features/profile/presentation/profile_page.dart apps/mobile/test/profile_message_action_test.dart
git commit -m "feat: require follows for profile messaging"
```

### Task 5: Refresh Current Documentation

**Files:**
- Modify: `Project_Overview.md`
- Modify: `apps/mobile/README.md`
- Modify: `supabase/README.md`

- [ ] **Step 1: Update the current project handoff**

Record these exact boundaries:

- F009 active mobile chat is relationship-gated and group candidates match Followers/Following.
- Message requests are hidden/dormant, not deleted.
- Existing accepted conversations, history, and realtime behavior are unchanged.
- Previous `parent_supervision.sql`, `chat.sql`, and `admin_portal.sql` versions were applied by the user.
- The newly updated `chat.sql` must be rerun before live acceptance.
- Remove the message-request Accept UI and accepted-chat group eligibility items from the active roadmap; replace them with one live reapplication/verification item.

Update the mobile README feature summary and add a Supabase README note explaining why request SQL remains present and why comments would not disable installed objects.

- [ ] **Step 2: Check documentation consistency**

Run:

```powershell
rg -n "Requests filters|recipient-side Accept|accepted recent direct-chat|message requests" Project_Overview.md apps/mobile/README.md supabase/README.md
git diff --check
```

Expected: current docs consistently describe the feature as dormant and the active group rule as Followers/Following only; historical specs/plans are unchanged; `git diff --check` exits 0.

- [ ] **Step 3: Commit documentation**

```powershell
git add -- Project_Overview.md apps/mobile/README.md supabase/README.md docs/superpowers/plans/2026-09-02-hidden-message-requests-and-chat-conformance.md
git commit -m "docs: record active chat relationship rules"
```

### Task 6: Complete Regression Verification

**Files:**
- Verify all files changed in Tasks 1-5.

- [ ] **Step 1: Run focused chat and profile tests**

Run:

```powershell
cd apps/mobile
flutter test test/chat_sql_migration_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/profile_message_action_test.dart test/chat_models_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 2: Run the complete Flutter suite**

Run:

```powershell
cd apps/mobile
flutter test
```

Expected: all tests pass with zero failures.

- [ ] **Step 3: Run static analysis**

Run:

```powershell
cd apps/mobile
flutter analyze
```

Expected: `No issues found!`.

- [ ] **Step 4: Inspect the final repository state**

Run:

```powershell
git status --short
git log -6 --oneline
```

Expected: no uncommitted implementation changes, and the design, SQL, Flutter, tests, and documentation commits are present.

- [ ] **Step 5: Hand off the Supabase action**

Report that the updated `supabase/chat.sql` must be run in the Supabase SQL Editor. Explain that rerunning preserves existing data and dormant request infrastructure while replacing the active relationship/group functions. Do not claim hosted verification because SQL application remains a user action.
