# Group Chat Mentions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add structured group-chat member mentions, admin-only `@all`, tappable dark-green mention spans, one recipient event per message, and oldest-first unread mention navigation.

**Architecture:** Store visible mention occurrences and recipient visit state in normalized `chat_message_mentions` rows created atomically by `send_chat_message`. Hydrate those rows into focused Dart mention models, keep composer parsing in a small controller, and extend existing chat room/tile widgets without moving chat events into Activity.

**Tech Stack:** PostgreSQL/Supabase RLS and RPCs, Flutter/Dart, Supabase Flutter, SharedPreferences, Flutter widget/unit tests.

---

## File Structure

- Create `apps/mobile/lib/src/features/chat/data/chat_mention.dart`: immutable mention entity plus JSON/RPC serialization and deduplication helpers.
- Create `apps/mobile/lib/src/features/chat/presentation/chat_mention_controller.dart`: composer query detection, entity insertion, edit reconciliation, and suggestion filtering.
- Modify `supabase/chat.sql`: mention table, indexes, RLS, RPC validation/insertion, unread mention queries, and visit RPC.
- Modify `apps/mobile/lib/src/features/chat/data/chat_models.dart`: attach mention entities and unvisited-mention summary to messages/conversations.
- Modify `apps/mobile/lib/src/features/chat/data/chat_repository.dart`: send/fetch mention metadata and mark mention targets visited.
- Modify `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`: member loading, autocomplete, mention-aware sending/cache, initial positioning, and floating `@` traversal.
- Modify `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`: rich mention rendering, profile taps, mention indicator, suggestion panel, and mention navigation button.
- Modify `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`: pass mention-aware conversation state through existing tiles/room navigation.
- Modify `apps/mobile/test/chat_models_test.dart`, `chat_repository_test.dart`, `chat_sql_migration_test.dart`, and `chat_widgets_test.dart`: focused regression coverage.
- Modify `Project_Overview.md`, `apps/mobile/README.md`, `supabase/README.md`, and `docs/setup.md`: implementation boundary and manual SQL instructions.

### Task 1: Define Mention Models and Composer Semantics

**Files:**
- Create: `apps/mobile/lib/src/features/chat/data/chat_mention.dart`
- Create: `apps/mobile/lib/src/features/chat/presentation/chat_mention_controller.dart`
- Test: `apps/mobile/test/chat_models_test.dart`

- [ ] **Step 1: Write failing model and controller tests**

Add tests that construct repeated mention occurrences, verify recipient deduplication, detect the active `@` query, keep repeated occurrences, and invalidate a span edited into a different token:

```dart
test('mention occurrences allow repeats but recipients are deduplicated', () {
  const mentions = [
    ChatMention(userId: 'u1', displayText: '@Ava', start: 0, end: 4),
    ChatMention(userId: 'u1', displayText: '@Ava', start: 9, end: 13),
  ];
  expect(ChatMention.uniqueRecipientIds(mentions), ['u1']);
});

test('controller detects query and preserves repeated selected mentions', () {
  final controller = ChatMentionController();
  expect(controller.queryFor('Hi @av', 6), 'av');
  controller.insertMention(
    text: 'Hi @av',
    selectionOffset: 6,
    userId: 'u1',
    displayName: 'Ava',
  );
  final second = controller.insertMention(
    text: '${controller.text}@a',
    selectionOffset: controller.text.length + 2,
    userId: 'u1',
    displayName: 'Ava',
  );
  expect(second.mentions, hasLength(2));
  expect(ChatMention.uniqueRecipientIds(second.mentions), ['u1']);
});
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `flutter test test/chat_models_test.dart`

Expected: compilation fails because `ChatMention` and `ChatMentionController` do not exist.

- [ ] **Step 3: Implement the immutable model and controller**

Implement these public contracts:

```dart
class ChatMention {
  const ChatMention({
    required this.userId,
    required this.displayText,
    required this.start,
    required this.end,
    this.isAll = false,
    this.visitedAt,
  });

  final String userId;
  final String displayText;
  final int start;
  final int end;
  final bool isAll;
  final DateTime? visitedAt;

  bool matches(String text) =>
      start >= 0 && end <= text.length && start < end &&
      text.substring(start, end) == displayText;

  Map<String, Object> toRpcMap() => {
    'user_id': userId,
    'display_text': displayText,
    'start_offset': start,
    'end_offset': end,
    'is_all': isAll,
  };

  static List<String> uniqueRecipientIds(Iterable<ChatMention> values) =>
      values.where((value) => !value.isAll).map((value) => value.userId).toSet().toList();
}
```

`ChatMentionController` must own the current validated occurrences, detect only an `@query` starting at a token boundary, replace the active query with `@Display Name ` or `@all `, adjust later offsets after edits, and remove entities whose recorded substring no longer matches.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run: `flutter test test/chat_models_test.dart`

Expected: all model/controller tests pass.

- [ ] **Step 5: Commit the model boundary**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_mention.dart apps/mobile/lib/src/features/chat/presentation/chat_mention_controller.dart apps/mobile/test/chat_models_test.dart
git commit -m "feat: model group chat mentions"
```

### Task 2: Add the Supabase Mention Contract

**Files:**
- Modify: `supabase/chat.sql`
- Test: `apps/mobile/test/chat_sql_migration_test.dart`

- [ ] **Step 1: Write failing SQL contract tests**

Assert that `chat.sql` contains the mention table, unique occurrence constraint, RLS, JSONB mention parameter, group/admin validation, unread RPCs, visit RPC, cascade deletion, grants, and no Activity notification insertion for chat mentions:

```dart
test('chat SQL defines normalized mention lifecycle', () {
  final sql = File('../../supabase/chat.sql').readAsStringSync();
  expect(sql, contains('create table if not exists public.chat_message_mentions'));
  expect(sql, contains('unique (message_id, mentioned_user_id, start_offset)'));
  expect(sql, contains("p_mentions jsonb default '[]'::jsonb"));
  expect(sql, contains('fetch_unvisited_chat_mentions'));
  expect(sql, contains('mark_chat_mention_visited'));
  expect(sql, contains("v_conversation.type <> 'group'"));
  expect(sql, contains("v_mention->>'is_all'"));
});
```

- [ ] **Step 2: Run SQL tests and confirm RED**

Run: `flutter test test/chat_sql_migration_test.dart`

Expected: assertions fail because mention SQL is absent.

- [ ] **Step 3: Add schema, RLS, RPCs, and atomic send validation**

Add the table with `message_id`, `mentioned_user_id`, `display_text`, offsets, `is_all_source`, timestamps, foreign keys, and the unique occurrence constraint. Add indexes for `(mentioned_user_id, visited_at, created_at)` and `(message_id, start_offset)`.

Replace the send signature with:

```sql
create or replace function public.send_chat_message(
  p_conversation_id uuid,
  p_body text,
  p_mentions jsonb default '[]'::jsonb
) returns uuid
```

Validate `jsonb_typeof(p_mentions) = 'array'`; limit visible mention entities to 100; validate integer offsets against the trimmed stored body; require group type; require active target membership; and require the sender's active `is_admin` membership for `@all`. Insert visible rows after inserting the message. Expand `@all` to all other active members while preserving one row per recipient/span, and use `distinct` recipient queries when calculating events.

Add:

```sql
public.fetch_unvisited_chat_mentions(p_conversation_id uuid default null)
public.mark_chat_mention_visited(p_message_id uuid)
```

The fetch RPC returns one oldest-first row per `(message_id, current_user)` and respects membership, `cleared_at`, message deletion, and deleted-for-me state. The visit RPC updates only the authenticated recipient's rows for that message. Revoke public/anon execution and grant authenticated execution.

- [ ] **Step 4: Run SQL contract tests and confirm GREEN**

Run: `flutter test test/chat_sql_migration_test.dart`

Expected: all SQL contract tests pass.

- [ ] **Step 5: Commit the database contract**

```powershell
git add supabase/chat.sql apps/mobile/test/chat_sql_migration_test.dart
git commit -m "feat: add group chat mention schema"
```

### Task 3: Hydrate Mentions Through Models, Repository, and Cache

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/data/chat_models.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Test: `apps/mobile/test/chat_models_test.dart`
- Test: `apps/mobile/test/chat_repository_test.dart`

- [ ] **Step 1: Write failing hydration and repository tests**

Cover `ChatMessage.fromMap` parsing nested `chat_message_mentions`, JSON cache round-tripping, `sendMessage` passing `p_mentions`, oldest-first unvisited fetch, and visit RPC parameters.

```dart
test('message parses mention entities', () {
  final message = ChatMessage.fromMap({
    'id': 'm1', 'conversation_id': 'c1', 'sender_id': 'u2',
    'body': 'Hi @Ava', 'created_at': '2026-07-12T00:00:00Z',
    'chat_message_mentions': [
      {'mentioned_user_id': 'u1', 'display_text': '@Ava', 'start_offset': 3, 'end_offset': 7}
    ],
  }, currentUserId: 'u1');
  expect(message.mentions.single.userId, 'u1');
});
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run: `flutter test test/chat_models_test.dart test/chat_repository_test.dart`

Expected: failures for missing mention fields, constants, and methods.

- [ ] **Step 3: Implement hydration and repository calls**

Add `List<ChatMention> mentions` to `ChatMessage`, `bool hasUnvisitedMention` and `String? oldestUnvisitedMentionMessageId` to `ChatConversation`, and an `UnvisitedChatMention` value object.

Extend `_messageSelectColumns` with:

```dart
'chat_message_mentions(mentioned_user_id, display_text, start_offset, end_offset, is_all_source, visited_at)'
```

Change `sendMessage` to accept `List<ChatMention> mentions = const []` and send `p_mentions: mentions.where((m) => m.matches(body)).map((m) => m.toRpcMap()).toList()`. Add `fetchUnvisitedMentions({String? conversationId})` and `markMentionVisited(String messageId)`.

Include mention maps in `_messageToJson` and `_decodeMessages` so recent cached bubbles remain rich offline.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run: `flutter test test/chat_models_test.dart test/chat_repository_test.dart`

Expected: all focused tests pass.

- [ ] **Step 5: Commit data flow**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_models.dart apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/test/chat_models_test.dart apps/mobile/test/chat_repository_test.dart
git commit -m "feat: hydrate chat mention metadata"
```

### Task 4: Build Mention Autocomplete and Admin-Only `@all`

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing composer widget tests**

Pump a group room with injected participants. Assert `@` opens filtered active members, normal members do not see `@all`, admins see it first, selection inserts a token, and repeated selection of one member produces repeated visible tokens.

```dart
testWidgets('admin sees @all first and can repeat a member mention', (tester) async {
  // Pump ChatRoomPage with a group conversation whose current user isAdmin.
  await tester.enterText(find.byType(TextField), '@');
  await tester.pump();
  expect(find.text('@all'), findsOneWidget);
  expect(find.text('Ava'), findsOneWidget);
  await tester.tap(find.text('Ava'));
  await tester.enterText(find.byType(TextField), '@Ava @');
  await tester.pump();
  expect(find.text('Ava'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget tests and confirm RED**

Run: `flutter test test/chat_widgets_test.dart`

Expected: autocomplete widget and injection contracts are missing.

- [ ] **Step 3: Implement the suggestion panel and composer wiring**

Add injectable participant loading for tests, load active participants once for group rooms, derive sender admin state from `ChatParticipant.isAdmin`, and update `ChatMentionController` from `TextEditingController` changes.

Create `ChatMentionSuggestions` in `chat_widgets.dart` with a first `@all` row only when `canMentionAll`, then avatar/name rows filtered case-insensitively. Place it directly above the composer within the bottom `SafeArea`. Selection replaces only the active query and restores input focus.

On send, pass validated structured occurrences; clear the mention controller only after a successful send and retain both text and entities after failure.

- [ ] **Step 4: Run widget tests and confirm GREEN**

Run: `flutter test test/chat_widgets_test.dart`

Expected: composer tests and prior chat widget tests pass.

- [ ] **Step 5: Commit autocomplete**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: add group mention autocomplete"
```

### Task 5: Render Tappable Dark-Green Mention Spans

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing rendering/navigation tests**

Assert each repeated occurrence renders dark green, normal mention taps call a profile callback with its stable user ID, `@all` is styled but not tappable, and selection mode keeps whole-bubble selection behaviour.

```dart
testWidgets('mention span opens stable profile id', (tester) async {
  String? openedId;
  await tester.pumpWidget(ChatMessageBubble(
    body: 'Hi @Ava and @Ava',
    isMine: false,
    mentions: const [
      ChatMention(userId: 'u1', displayText: '@Ava', start: 3, end: 7),
      ChatMention(userId: 'u1', displayText: '@Ava', start: 12, end: 16),
    ],
    onMentionTap: (id) => openedId = id,
  ));
  await tester.tap(find.text('@Ava').first);
  expect(openedId, 'u1');
});
```

- [ ] **Step 2: Run widget tests and confirm RED**

Run: `flutter test test/chat_widgets_test.dart`

Expected: `ChatMessageBubble` has no mention-aware rich text contract.

- [ ] **Step 3: Implement rich spans and profile navigation**

Extend `ChatMessageBubble` with `mentions` and `onMentionTap`. Replace plain text construction in `_InlineBubbleTextWithTime` with ordered `TextSpan`s split at validated occurrence offsets. Use the same dark green as comment mentions (`Color(0xFF166534)`), bold mention text, `TapGestureRecognizer` for normal user mentions, and no recognizer for `@all`.

In `ChatRoomPage`, open `ProfilePage(userId: id)` using the existing profile navigation pattern. Disable span taps while message selection mode is active.

- [ ] **Step 4: Run widget tests and confirm GREEN**

Run: `flutter test test/chat_widgets_test.dart`

Expected: rendering/navigation tests and prior widget tests pass.

- [ ] **Step 5: Commit mention rendering**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: render tappable chat mentions"
```

### Task 6: Add Conversation Indicator and Oldest-First Mention Navigation

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Test: `apps/mobile/test/chat_repository_test.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing indicator and traversal tests**

Cover conversation `@` indicator visibility, opening a room at the oldest unvisited mention, floating button placement above jump-to-bottom, repeated occurrences yielding one target, chronological traversal, optimistic visit marking, and disappearance after the last target.

```dart
testWidgets('@ button traverses one target per mentioned message', (tester) async {
  // Pump messages m1/m2 with current-user mentions and injected visit callback.
  expect(find.byKey(const ValueKey('mention-navigation-button')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('mention-navigation-button')));
  await tester.pumpAndSettle();
  expect(visitedMessageIds, ['m1']);
});
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run: `flutter test test/chat_repository_test.dart test/chat_widgets_test.dart`

Expected: indicator and navigation behaviour are absent.

- [ ] **Step 3: Implement unread summary and room navigation**

When loading chat home state, fetch unvisited mention summaries once and merge them into conversations by ID. Add an `@` glyph immediately before the unread badge in `_ConversationPreviewLine`.

In `ChatRoomPage`, keep a chronological unique list of unvisited message IDs. Initial positioning prefers the oldest unvisited mention over the normal unread divider. Use existing `_messageKeys` and `Scrollable.ensureVisible` to reveal targets. Add `MentionNavigationButton` at `bottom: _showJumpToBottom ? 66 : 14`, leaving the jump button at `14`. After reveal, optimistically remove the ID, call `markMentionVisited`, and restore it on RPC failure during the next refresh.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run: `flutter test test/chat_repository_test.dart test/chat_widgets_test.dart`

Expected: indicator/traversal tests and all existing focused tests pass.

- [ ] **Step 5: Commit navigation**

```powershell
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_repository_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: navigate unread group mentions"
```

### Task 7: Document Manual Supabase Application and Verify Regression Safety

**Files:**
- Modify: `Project_Overview.md`
- Modify: `apps/mobile/README.md`
- Modify: `supabase/README.md`
- Modify: `docs/setup.md`

- [ ] **Step 1: Update maintained documentation**

Document group mention autocomplete, repeated visible mentions with one recipient event, admin-only `@all`, chat-only mention indicators, and the later push boundary. State exactly:

```text
Manual database step: run the updated supabase/chat.sql in the Supabase SQL Editor.
This script is idempotent for schema objects, but inspect any SQL Editor error before rerunning it.
```

Include this verification query:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name = 'chat_message_mentions';

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'send_chat_message',
    'fetch_unvisited_chat_mentions',
    'mark_chat_mention_visited'
  )
order by routine_name;
```

- [ ] **Step 2: Format changed Dart files**

Run: `dart format lib test`

Expected: formatter exits successfully.

- [ ] **Step 3: Run focused chat suite**

Run: `flutter test test/chat_models_test.dart test/chat_repository_test.dart test/chat_sql_migration_test.dart test/chat_widgets_test.dart`

Expected: all focused chat tests pass.

- [ ] **Step 4: Run full mobile verification**

Run: `flutter test`

Expected: all mobile tests pass.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 5: Review final changes and commit documentation**

Run: `git status --short`

Run: `git diff --check`

Expected: only intended files are changed and no whitespace errors are reported.

```powershell
git add Project_Overview.md apps/mobile/README.md supabase/README.md docs/setup.md
git commit -m "docs: document group chat mentions"
```

### Task 8: Polish Mention UI From Device Feedback

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add failing widget and source-contract tests**

Cover the shared `#128C7E` accent, overlay positioning, four-row viewport, text-column dividers, keyboard dismissal, centered indicator/button glyphs, and shrink-wrapped mention-only bubbles.

- [ ] **Step 2: Run the focused widget suite and confirm RED**

Run: `flutter test test/chat_widgets_test.dart`

Expected: new layout/style assertions fail against the current implementation.

- [ ] **Step 3: Implement the approved overlay and visual polish**

Use one exported chat mention accent constant, move the panel from the composer column into the room stack, cap it at four 60-pixel rows, use separators indented by the avatar width plus gap, dismiss focus/query from empty chat taps, center both `@` glyphs, and add `widthFactor: 1` to the rich mention text alignment.

- [ ] **Step 4: Run focused and full verification**

Run: `flutter test test/chat_widgets_test.dart`

Run: `flutter test`

Run: `flutter analyze`

Expected: all tests pass and analyzer reports no issues.
