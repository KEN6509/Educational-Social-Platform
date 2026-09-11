# Mobile Chat Presentation Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split CyanZone's oversized mobile chat presentation libraries into cohesive feature-local part files without changing chat behaviour, public imports, realtime ownership, or UI values.

**Architecture:** Keep `chat_widgets.dart`, `chat_room_page.dart`, and `notification_sections_page.dart` as the owning Dart libraries. Move existing declarations into private `part` files so public types remain available through their current imports and page State classes retain all runtime coordination.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test

---

## Scope and constraints

- Work in the user's original CyanZone folder on the existing
  `refactor/mobile-architecture-optimization` branch. Do not create a worktree.
- Work only in `apps/mobile` and this plan document.
- Preserve every existing public constructor, import path, route, callback,
  colour, dimension, animation and interaction rule.
- Move complete declaration bodies without rewriting them.
- Keep repository construction, Supabase calls, caches, realtime channels,
  controllers, timers and page State logic in their current owning page.
- Do not change `chat_repository.dart`, `chat_models.dart`, SQL, API, Firebase,
  moderation, push delivery or direct-message follow enforcement.
- Use focused tests after each extraction. The complete mobile suite remains
  deferred to the final mobile checkpoint unless a focused failure requires a
  broader run.

## Target files

- `chat_widgets.dart`: imports, shared constants, `part` directives and shared
  time-formatting helpers.
- `chat_message_bubbles.dart`: text bubbles, shared-post cards, inline mention
  text and bubble timestamps.
- `chat_message_media.dart`: image-message layout, thumbnails, grids, preview,
  zoom and image failure widgets.
- `chat_list_widgets.dart`: avatars, search, conversation rows, participant
  rows, empty states and notification entry cards.
- `chat_room_page.dart`: public page and State coordinator.
- `chat_room_widgets.dart`: existing message-list, navigation, suggestion,
  separator and wallpaper declarations.
- `notification_sections_page.dart`: public page and State coordinator.
- `notification_section_widgets.dart`: existing notification row, filter,
  preview, badge and follower-action declarations.
- `chat_presentation_decomposition_test.dart`: structural ownership contracts.

### Task 0: Establish the clean baseline

**Files:**
- Verify: repository working tree
- Verify: current chat tests

- [ ] **Step 1: Confirm the branch and working tree**

Run from the repository root:

```powershell
git status --short --branch
git diff --check
```

Expected: branch is `refactor/mobile-architecture-optimization`, no source
files are modified, and `git diff --check` reports no errors.

- [ ] **Step 2: Run the pre-extraction chat baseline**

Run from `apps/mobile`:

```powershell
flutter test test/chat_widgets_test.dart test/chat_repository_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter compact
```

Expected: all selected tests pass. Stop and report any pre-existing failure
before moving declarations.

### Task 1: Extract message bubbles and shared-post presentation

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/chat_message_bubbles.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Create: `apps/mobile/test/chat_presentation_decomposition_test.dart`

- [ ] **Step 1: Write the failing message-bubble ownership test**

Create `chat_presentation_decomposition_test.dart` with:

```dart
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
```

- [ ] **Step 2: Run the new test and verify RED**

Run from `apps/mobile`:

```powershell
flutter test test/chat_presentation_decomposition_test.dart --plain-name "message bubbles live in their feature-local part" --no-pub
```

Expected: FAIL because the part directive and file do not exist.

- [ ] **Step 3: Move the complete message-bubble declarations**

Add this directive after the imports in `chat_widgets.dart`:

```dart
part 'chat_message_bubbles.dart';
```

Create `chat_message_bubbles.dart` beginning with:

```dart
part of 'chat_widgets.dart';
```

Move these complete declarations from `chat_widgets.dart`, without changing
their bodies or order:

```text
ChatMessageBubble
_SharedPostBubbleContent
_SharedPostImageCardBody
_SharedPostTextCardBody
_SharedPostAuthorRow
_SharedPostFallbackAvatar
_InlineBubbleTextWithTime
_bubbleTimestampStyle
```

Leave `_formatBubbleTime` in `chat_widgets.dart`; the part file can use its
private library helper.

- [ ] **Step 4: Format and verify the bubble extraction**

Run from `apps/mobile`:

```powershell
dart format lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_message_bubbles.dart test/chat_presentation_decomposition_test.dart
flutter analyze --no-pub lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_message_bubbles.dart test/chat_presentation_decomposition_test.dart
flutter test test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart --no-pub --reporter compact
```

Expected: analysis succeeds and all selected tests pass.

- [ ] **Step 5: Commit the bubble extraction**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/lib/src/features/chat/presentation/chat_message_bubbles.dart apps/mobile/test/chat_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract chat message bubbles"
```

### Task 2: Extract image-message and preview presentation

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/chat_message_media.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Modify: `apps/mobile/test/chat_presentation_decomposition_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add the failing media ownership test**

Append inside `main()` in `chat_presentation_decomposition_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the media test and verify RED**

```powershell
flutter test test/chat_presentation_decomposition_test.dart --plain-name "chat message media lives in its feature-local part" --no-pub
```

Expected: FAIL because the media part does not exist.

- [ ] **Step 3: Move the complete media declarations**

Add:

```dart
part 'chat_message_media.dart';
```

Create `chat_message_media.dart` beginning with:

```dart
part of 'chat_widgets.dart';
```

Move these declarations without modifying their bodies:

```text
_ImageBubbleContent
_SingleImageBubbleThumbnail
_SingleImageBubbleThumbnailState
_ImageTimePill
_ChatImagePreviewPage
_ChatImagePreviewPageState
_ChatImageLoadError
_ImageBubbleGrid
_GridImage
_ChatImageThumbnailLoadError
```

- [ ] **Step 4: Preserve the existing media source contract**

In `chat_widgets_test.dart`, change
`chat preview downloads real images and keeps thumbnail errors quiet` to read
the root and media sources:

```dart
final widgetSource =
    File('lib/src/features/chat/presentation/chat_widgets.dart')
        .readAsStringSync();
final mediaSource =
    File('lib/src/features/chat/presentation/chat_message_media.dart')
        .readAsStringSync();
final source = '$widgetSource\n$mediaSource';
```

Keep the existing assertions unchanged.

- [ ] **Step 5: Format and verify the media extraction**

```powershell
dart format lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_message_media.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter analyze --no-pub lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_message_media.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter test test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart --no-pub --reporter compact
```

Expected: analysis succeeds and all selected tests pass.

- [ ] **Step 6: Commit the media extraction**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/lib/src/features/chat/presentation/chat_message_media.dart apps/mobile/test/chat_presentation_decomposition_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): extract chat message media"
```

### Task 3: Extract chat list and common presentation widgets

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/chat_list_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Modify: `apps/mobile/test/chat_presentation_decomposition_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add the failing list-widget ownership test**

Append inside `main()`:

```dart
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
```

- [ ] **Step 2: Run the list-widget test and verify RED**

```powershell
flutter test test/chat_presentation_decomposition_test.dart --plain-name "chat list widgets live in their feature-local part" --no-pub
```

Expected: FAIL because the list part does not exist.

- [ ] **Step 3: Move the complete list declarations**

Add:

```dart
part 'chat_list_widgets.dart';
```

Create `chat_list_widgets.dart` beginning with:

```dart
part of 'chat_widgets.dart';
```

Move these declarations without changing their bodies:

```text
ChatAvatar
ChatNoSplash
GroupAvatar
_comfortableGroupColor
ChatSearchField
ChatAvatarWithBadge
ConversationTile
_ConversationTileState
_ConversationPreviewLine
_ConversationMentionIndicator
ChatParticipantRow
_ParticipantActionSlot
_AdminBadge
ChatNoResultsState
ChatEmptyState
NotificationEntryCard
```

Keep `_formatPreviewDateTime`, `_formatChatTime`, and `_weekdayLabel` in the
owning root file for this structural checkpoint.

- [ ] **Step 4: Point the conversation source contract at the new part**

In `conversation rows place unread badge on preview line`, read:

```dart
final source =
    File('lib/src/features/chat/presentation/chat_list_widgets.dart')
        .readAsStringSync();
```

Keep the existing assertions unchanged.

- [ ] **Step 5: Format and verify the list extraction**

```powershell
dart format lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_list_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter analyze --no-pub lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_list_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter test test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart test/unread_badge_test.dart --no-pub --reporter compact
```

Expected: analysis succeeds and all selected tests pass.

- [ ] **Step 6: Commit the list extraction**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/lib/src/features/chat/presentation/chat_list_widgets.dart apps/mobile/test/chat_presentation_decomposition_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): extract chat list widgets"
```

### Task 4: Extract existing chat-room visual declarations

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/chat_room_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/test/chat_presentation_decomposition_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add the failing room-widget ownership test**

Append inside `main()`:

```dart
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
```

- [ ] **Step 2: Run the room-widget test and verify RED**

```powershell
flutter test test/chat_presentation_decomposition_test.dart --plain-name "chat room visual widgets live in their feature-local part" --no-pub
```

Expected: FAIL because the room part does not exist.

- [ ] **Step 3: Move all existing declarations after the page State**

Add after the imports in `chat_room_page.dart`:

```dart
part 'chat_room_widgets.dart';
```

Create `chat_room_widgets.dart` beginning with:

```dart
part of 'chat_room_page.dart';
```

Move these declarations without changing their bodies or order:

```text
_MessageList
_JumpToBottomButton
_MentionNavigationButton
_MentionSuggestionsPanel
_MentionSuggestionRow
_GroupCreationNotice
_DateSeparator
_UnreadMessagesDivider
_isSameDate
_formatDateSeparator
_WhatsAppRoomBackground
_ChatWallpaperPainter
```

Keep `ChatRoomPage`, `_ChatRoomPageState`, every controller, timer, callback,
message operation and realtime channel in `chat_room_page.dart`.

- [ ] **Step 4: Preserve the room source contract across the split**

In `chat room supports initial unread target and jump to bottom button`, use:

```dart
final pageSource =
    File('lib/src/features/chat/presentation/chat_room_page.dart')
        .readAsStringSync();
final widgetSource =
    File('lib/src/features/chat/presentation/chat_room_widgets.dart')
        .readAsStringSync();
final source = '$pageSource\n$widgetSource';
```

Keep the current assertions unchanged.

- [ ] **Step 5: Format and verify the room extraction**

```powershell
dart format lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_room_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter analyze --no-pub lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_room_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter test test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter compact
```

Expected: analysis succeeds and all selected tests pass.

- [ ] **Step 6: Commit the room extraction**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/lib/src/features/chat/presentation/chat_room_widgets.dart apps/mobile/test/chat_presentation_decomposition_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): extract chat room widgets"
```

### Task 5: Extract notification-section presentation widgets

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/notification_section_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/test/chat_presentation_decomposition_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add the failing notification ownership test**

Append inside `main()`:

```dart
test('notification section widgets live in their feature-local part', () {
  final root =
      File('$path/notification_sections_page.dart').readAsStringSync();
  final widgetFile = File('$path/notification_section_widgets.dart');

  expect(root, contains("part 'notification_section_widgets.dart';"));
  expect(widgetFile.existsSync(), isTrue);
  if (!widgetFile.existsSync()) return;

  final widgets = widgetFile.readAsStringSync();
  expect(widgets, startsWith("part of 'notification_sections_page.dart';"));
  expect(widgets, contains('class _FollowerOrGenericNotificationTile'));
  expect(widgets, contains('class _ActivityFilterDropdown'));
  expect(widgets, contains('class _ActivityNotificationTile'));
  expect(widgets, contains('class _ActivityPostPreview'));
  expect(widgets, contains('class _FollowerActionButton'));
  expect(widgets, contains('String _formatNotificationTime'));
  expect(root, isNot(contains('class _ActivityNotificationTile')));
  expect(root, isNot(contains('class _FollowerActionButton')));
});
```

- [ ] **Step 2: Run the notification test and verify RED**

```powershell
flutter test test/chat_presentation_decomposition_test.dart --plain-name "notification section widgets live in their feature-local part" --no-pub
```

Expected: FAIL because the notification part does not exist.

- [ ] **Step 3: Move the complete notification widget declarations**

Add after the imports in `notification_sections_page.dart`:

```dart
part 'notification_section_widgets.dart';
```

Create `notification_section_widgets.dart` beginning with:

```dart
part of 'notification_sections_page.dart';
```

Move every existing declaration after `_NotificationSectionsPageState`:

```text
_FollowerOrGenericNotificationTile
_NotificationRowText
_NotificationUnreadDot
_NotificationLeadingAvatar
_ActivityFilterChip
_ActivityFilterDropdown
_ActivityNotificationTile
_ActivityAvatar
_ActivityBadge
_ActivityPostPreview
_FollowerActionButton
_FollowerActionButtonState
_formatNotificationTime
```

Keep all typedefs, `NotificationSectionsPage`, its State, loading, routing,
read-state, deletion and realtime code in the owning page.

- [ ] **Step 4: Preserve the notification source contracts**

For `notification divider aligns with notification row text` and
`follow back uses follow-only profile flow and not toggle helper`, read:

```dart
final source = File(
  'lib/src/features/chat/presentation/notification_section_widgets.dart',
).readAsStringSync();
```

For `notification page refresh resets follower action state`, combine both
sources because refresh state remains on the page and the keyed follower
button moves:

```dart
final pageSource = File(
  'lib/src/features/chat/presentation/notification_sections_page.dart',
).readAsStringSync();
final widgetSource = File(
  'lib/src/features/chat/presentation/notification_section_widgets.dart',
).readAsStringSync();
final source = '$pageSource\n$widgetSource';
```

Keep `activity notifications pass comment id into post detail page` reading
the owning page because navigation stays in its State.

- [ ] **Step 5: Format and verify the notification extraction**

```powershell
dart format lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/chat/presentation/notification_section_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter analyze --no-pub lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/chat/presentation/notification_section_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
flutter test test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart test/chat_repository_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter compact
```

Expected: analysis succeeds and all selected tests pass.

- [ ] **Step 6: Commit the notification extraction**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/lib/src/features/chat/presentation/notification_section_widgets.dart apps/mobile/test/chat_presentation_decomposition_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): extract notification section widgets"
```

### Task 6: Complete the Phase 4A checkpoint

**Files:**
- Verify: all Phase 4A production and test files
- Modify only if verification exposes a structural regression within Phase 4A

- [ ] **Step 1: Verify all structural boundaries**

```powershell
flutter test test/chat_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: all five ownership tests pass.

- [ ] **Step 2: Run the complete focused chat regression set**

```powershell
flutter test test/chat_widgets_test.dart test/chat_repository_test.dart test/app_confirmation_dialog_test.dart test/app_feedback_test.dart test/unread_badge_test.dart test/cyanzone_bottom_navigation_test.dart --no-pub --reporter compact
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 3: Run complete mobile static analysis**

```powershell
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4: Verify formatting and repository cleanliness**

```powershell
dart format lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_message_bubbles.dart lib/src/features/chat/presentation/chat_message_media.dart lib/src/features/chat/presentation/chat_list_widgets.dart lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_room_widgets.dart lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/chat/presentation/notification_section_widgets.dart test/chat_presentation_decomposition_test.dart test/chat_widgets_test.dart
```

Run from the repository root:

```powershell
git diff --check
git status --short --branch
```

Expected: formatting makes no further changes, Git reports no whitespace
errors, and no Phase 4A implementation change remains uncommitted.

- [ ] **Step 5: Record the checkpoint result**

Do not create an empty commit. If verification requires a focused correction,
write a failing regression test, apply only the correction, rerun Steps 1-4,
and commit:

```powershell
git commit -m "fix(mobile): close chat decomposition checkpoint gaps"
```

## Completion gate

Phase 4A is complete when all five structural tests and the focused chat suite
pass, complete mobile analysis reports no issues, existing public imports
compile unchanged, and the working tree is clean. Phase 4B realtime lifecycle
and refresh optimization requires a separate approved design before runtime
behaviour changes.
