# Chat Push and Transparent Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give direct and group chat pushes conversation-aware text while removing only the full-width background surrounding the responsive floating navigation pill.

**Architecture:** The API repository will enrich notification rows through their existing actor and conversation foreign keys, and a pure push-presentation function will format only chat pushes before Firebase delivery. Flutter will retain its safe-area ownership and white navigation pill while changing that navigation instance's outer `BottomSafeSurface` color to transparent.

**Tech Stack:** Node.js, TypeScript, Node test runner, Supabase/PostgREST, Firebase Admin, Flutter/Dart, Flutter widget tests

---

## File map

- `services/api/src/push/pushRepository.ts` — load and map sender/conversation metadata with an authoritative notification row.
- `services/api/src/push/pushRepository.test.ts` — verify relation selection and nullable metadata mapping.
- `services/api/src/push/pushService.ts` — derive Firebase-visible chat notification text without altering non-chat pushes.
- `services/api/src/push/pushService.test.ts` — specify direct, group, fallback, and non-chat presentation behavior.
- `apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart` — make only the navigation's outer safe-area surface transparent.
- `apps/mobile/test/cyanzone_bottom_navigation_test.dart` — preserve bottom anchoring, safe-area height, and white pill styling while asserting a transparent outer surface.

### Task 1: Format direct and group chat push notifications

**Files:**
- Modify: `services/api/src/push/pushRepository.ts`
- Modify: `services/api/src/push/pushRepository.test.ts`
- Modify: `services/api/src/push/pushService.ts`
- Modify: `services/api/src/push/pushService.test.ts`

- [ ] **Step 1: Write failing repository and presentation tests**

Extend the `PushSourceRecord` test fixture contract with nullable metadata and add focused assertions equivalent to:

```ts
assert.equal(source?.actorName, 'Ken');
assert.equal(source?.conversationType, 'group');
assert.equal(source?.conversationTitle, 'Study Group');
assert.match(selectedNotificationColumns, /notifications_actor_id_fkey/);
assert.match(selectedNotificationColumns, /notifications_conversation_id_fkey/);

assert.deepEqual(pushPresentationFor(source({
  conversationType: 'direct',
  actorName: 'Ken',
  body: "How's it going?",
})), {
  title: 'Ken',
  body: "How's it going?",
});

assert.deepEqual(pushPresentationFor(source({
  conversationType: 'group',
  conversationTitle: 'Classmates',
  actorName: 'Ken',
  body: "How's going guys?",
})), {
  title: 'Classmates',
  body: "Ken: How's going guys?",
});
```

Also assert that missing names fall back to the stored title/body and that a non-chat source is returned unchanged.

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
cd services/api
& 'C:\Users\KEN\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' node_modules/tsx/dist/cli.mjs --test src/push/pushRepository.test.ts src/push/pushService.test.ts
```

Expected: FAIL because `PushSourceRecord` has no relation metadata and `pushPresentationFor` does not exist.

- [ ] **Step 3: Enrich authoritative notification rows**

For `notifications`, extend the select with explicit aliases for its existing foreign keys:

```ts
actor:profiles!notifications_actor_id_fkey(name),
conversation:chat_conversations!notifications_conversation_id_fkey(type,title)
```

Add these fields to `PushSourceRecord`:

```ts
actorName: string | null;
conversationType: string | null;
conversationTitle: string | null;
```

Map each nested value defensively through an `isRecord` check and `nullableString`. Supervision sources set all three fields to `null` naturally because the relationships are absent.

- [ ] **Step 4: Implement the pure push-presentation function**

Add and use:

```ts
export function pushPresentationFor(
  source: PushSourceRecord,
): {title: string; body: string} {
  const fallback = {
    title: source.title || 'CyanZone',
    body: source.body || 'You have a new CyanZone notification.',
  };
  if (source.eventType !== 'chat_message') return fallback;

  const sender = source.actorName?.trim() || null;
  if (source.conversationType === 'group') {
    return {
      title: source.conversationTitle?.trim() || fallback.title,
      body: sender ? `${sender}: ${fallback.body}` : fallback.body,
    };
  }
  return {title: sender || fallback.title, body: fallback.body};
}
```

`createMessage` must use this result for `title` and `body` while leaving destination data and channel selection unchanged.

- [ ] **Step 5: Run focused API tests and verify GREEN**

Run the Step 2 command again.

Expected: all focused push repository/service tests pass.

- [ ] **Step 6: Commit the push presentation change**

```powershell
git add services/api/src/push/pushRepository.ts services/api/src/push/pushRepository.test.ts services/api/src/push/pushService.ts services/api/src/push/pushService.test.ts
git commit -m "feat(api): personalize chat push notifications"
```

### Task 2: Make the navigation surround transparent

**Files:**
- Modify: `apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart`
- Modify: `apps/mobile/test/cyanzone_bottom_navigation_test.dart`

- [ ] **Step 1: Change the widget test expectation before production code**

In both bottom-inset cases, require the navigation-owned safe-area surface to be transparent while confirming the decorated pill remains white:

```dart
expect(surface.color, Colors.transparent);

final decoration = decorated.decoration as BoxDecoration;
expect(decoration.color, AppColors.surface);
expect(decoration.borderRadius, BorderRadius.circular(AppRadii.navigation));
```

- [ ] **Step 2: Run the focused widget test and verify RED**

Run:

```powershell
cd apps/mobile
flutter test test/cyanzone_bottom_navigation_test.dart
```

Expected: FAIL because the outer surface currently uses `AppColors.background`.

- [ ] **Step 3: Make only the navigation wrapper transparent**

Change the `CyanZoneBottomNavigation` instance to:

```dart
return BottomSafeSurface(
  color: Colors.transparent,
  padding: const EdgeInsets.all(AppLayout.floatingNavigationOuterMargin),
  child: ...,
);
```

Do not change `BottomSafeSurface`'s default, the inner `DecoratedBox`, `MainShell.extendBody`, or chat-composer usage.

- [ ] **Step 4: Format and verify GREEN**

Run:

```powershell
cd apps/mobile
dart format lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart test/cyanzone_bottom_navigation_test.dart
flutter test test/cyanzone_bottom_navigation_test.dart test/bottom_safe_surface_test.dart
```

Expected: all navigation and safe-area tests pass.

- [ ] **Step 5: Commit the navigation change**

```powershell
git add apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart apps/mobile/test/cyanzone_bottom_navigation_test.dart
git commit -m "fix(mobile): reveal content around floating navigation"
```

### Task 3: Full verification and release APK

**Files:**
- Verify all branch changes.
- Build ignored artifact: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 1: Run Flutter static analysis**

Run: `cd apps/mobile && flutter analyze`

Expected: `No issues found!`.

- [ ] **Step 2: Run the complete Flutter suite**

Run: `cd apps/mobile && flutter test`

Expected: all tests pass.

- [ ] **Step 3: Run the complete API suite**

Run:

```powershell
cd services/api
& 'C:\Users\KEN\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' node_modules/tsx/dist/cli.mjs --test src/all.test.ts
```

Expected: all API tests pass.

- [ ] **Step 4: Review the complete branch**

Run:

```powershell
git diff --check origin/main...HEAD
git status --short --branch
```

Expected: no whitespace errors and a clean tracked working tree.

- [ ] **Step 5: Build and fingerprint the release APK**

Run:

```powershell
cd apps/mobile
flutter build apk --release
Get-FileHash -Algorithm SHA256 build/app/outputs/flutter-apk/app-release.apk
```

Expected: the APK is rebuilt successfully and a new SHA-256 is recorded for the user.

- [ ] **Step 6: Record deployment and device acceptance requirements**

The mobile navigation change is present in the new APK. The push-presentation change requires deploying the updated `services/api` project to Vercel after this branch is merged. On physical devices, verify one direct push has `sender / message`, one group push has `group / sender: message`, and the feed remains visible around the white navigation pill on both viewport sizes.
