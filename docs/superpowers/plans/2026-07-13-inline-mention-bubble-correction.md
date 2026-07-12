# Inline Mention Bubble Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Center the room mention-navigation symbol with a vector icon and make all structured mention messages lay out like ordinary text bubbles without losing mention interactions.

**Architecture:** Keep mention parsing, persistence, and tap callbacks unchanged. Replace only the structured-mention presentation branch with the ordinary bubble's measured inline timestamp strategy, using `TextPainter` over an equivalent styled `TextSpan`; replace the navigation text glyph with Flutter's centered vector icon.

**Tech Stack:** Flutter, Dart, `flutter_test`

---

### Task 1: Lock the corrected presentation in widget tests

**Files:**
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add failing tests for the vector icon and mention layouts**

Add widget tests that:

```dart
expect(
  find.descendant(
    of: find.byKey(const ValueKey('mention-navigation-button')),
    matching: find.byIcon(Icons.alternate_email_rounded),
  ),
  findsOneWidget,
);
```

Pump both `@all` and `Hello @Ava again` messages with timestamps and valid `ChatMention` entities. Assert the bubble remains compact, the timestamp shares the mention text's vertical line when space permits, and tapping `@Ava` still invokes the original profile callback.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run from `apps/mobile`:

```powershell
flutter test test/chat_widgets_test.dart --plain-name "mention"
```

Expected: FAIL because the navigation button still renders a text glyph and structured mention timestamps remain in a separate column row.

- [ ] **Step 3: Commit the failing regression tests**

```powershell
git add apps/mobile/test/chat_widgets_test.dart
git commit -m "test: cover inline mention bubble layout"
```

### Task 2: Use a centered vector navigation icon

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart:1313`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Replace the text glyph**

Inside `_MentionNavigationButton`, retain the 42-pixel circular material control and replace its `Text('@')` with:

```dart
const Icon(
  Icons.alternate_email_rounded,
  color: chatMentionAccent,
  size: 24,
)
```

- [ ] **Step 2: Run the navigation test**

Run from `apps/mobile`:

```powershell
flutter test test/chat_widgets_test.dart --plain-name "room enters oldest mention"
```

Expected: PASS, including the vector-icon assertion and existing oldest-first traversal assertion.

- [ ] **Step 3: Commit the icon correction**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix: center mention navigation icon"
```

### Task 3: Unify mention and ordinary bubble layout

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart:1300`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Build an equivalent rich text span**

In `_InlineBubbleTextWithTime.build`, create the styled structured span once:

```dart
final mentionSpans = _mentionSpans();
final bodySpan = TextSpan(
  text: mentionSpans == null ? body : null,
  style: _bodyStyle,
  children: mentionSpans,
);
```

Use `bodySpan` for `TextPainter` measurement and for the displayed `Text.rich`, preserving every existing `WidgetSpan` and its `GestureDetector`.

- [ ] **Step 2: Apply ordinary timestamp placement to both text variants**

Remove the special mention `Column`. Reuse the existing `canShareLastLine` calculation for `bodySpan`; in the shared-line stack render `Text.rich(bodySpan)` with the timestamp positioned at bottom-right. In the wrapping branch render `Text.rich(bodySpan)` above the timestamp. Keep the existing `timeGap`, maximum width, explicit-newline handling, and shrink-wrapping calculations.

- [ ] **Step 3: Run the focused mention tests**

Run from `apps/mobile`:

```powershell
flutter test test/chat_widgets_test.dart --plain-name "mention"
```

Expected: PASS for `@all`, mixed text and mentions, repeated/clickable mentions, compact bubble width, and navigation behavior.

- [ ] **Step 4: Format and run the complete chat widget file**

```powershell
dart format lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_room_page.dart test/chat_widgets_test.dart
flutter test test/chat_widgets_test.dart
```

Expected: formatting succeeds and all chat widget tests pass.

- [ ] **Step 5: Commit the unified layout**

```powershell
git add apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix: lay out mentions like normal chat text"
```

### Task 4: Verify no regressions

**Files:**
- Verify: `apps/mobile`

- [ ] **Step 1: Run the complete Flutter suite**

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Inspect the final diff and repository state**

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only intentional plan/implementation commits are present and the worktree is clean.
