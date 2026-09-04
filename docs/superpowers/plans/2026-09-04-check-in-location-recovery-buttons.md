# Check-In Location Recovery Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the two location-recovery actions on Safety Check-In visually balanced, equally sized, touch-friendly, and clear about submission behavior.

**Architecture:** Keep the change local to the existing Check-In presentation widget. Reuse the current recovery flow and repository calls; only adjust the button layout, labels, and widget-level regression coverage.

**Tech Stack:** Flutter, Material buttons, Flutter widget tests

---

### Task 1: Balance the location-recovery actions

**Files:**
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart:283-310`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart:188-208`

- [ ] **Step 1: Extend the existing widget test so it describes the approved layout**

Update `check in location failure preserves message and offers choices` to use the phone viewport, locate keyed buttons, require the revised label, and compare their rendered sizes:

```dart
_usePhoneViewport(tester);

final retryButton = find.byKey(const Key('check-in-retry-location'));
final sendWithoutLocationButton =
    find.byKey(const Key('check-in-send-without-location'));

expect(retryButton, findsOneWidget);
expect(sendWithoutLocationButton, findsOneWidget);
expect(find.text('Send without location'), findsOneWidget);

final retrySize = tester.getSize(retryButton);
final sendWithoutLocationSize = tester.getSize(sendWithoutLocationButton);
expect(retrySize.width, closeTo(sendWithoutLocationSize.width, 0.1));
expect(retrySize.height, closeTo(sendWithoutLocationSize.height, 0.1));
expect(retrySize.height, greaterThanOrEqualTo(48));
```

Update the interaction assertion to tap `Send without location`.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart --plain-name "check in location failure preserves message and offers choices"
```

Expected: FAIL because the new button keys and `Send without location` label do not exist and the current buttons do not have equal widths.

- [ ] **Step 3: Implement the equal responsive button layout**

Replace the current recovery `Row` with two expanded actions inside `IntrinsicHeight`, stretching both buttons to the taller action while retaining a 52dp minimum height:

```dart
IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: OutlinedButton(
          key: const Key('check-in-retry-location'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _busy ? null : _captureLocation,
          child: const Text(
            'Retry location',
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton.tonal(
          key: const Key('check-in-send-without-location'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _busy
              ? null
              : () => _submit(const LocationCapture.notRequested()),
          child: const Text(
            'Send without location',
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ],
  ),
)
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```powershell
dart format lib/src/features/parent_child/presentation/check_in_page.dart test/parent_supervision_flows_test.dart
flutter test test/parent_supervision_flows_test.dart --plain-name "check in location failure preserves message and offers choices"
flutter test test/parent_supervision_flows_test.dart
flutter analyze lib/src/features/parent_child/presentation/check_in_page.dart test/parent_supervision_flows_test.dart
```

Expected: the focused test passes, all parent-supervision flow tests pass, and analysis reports no issues.

- [ ] **Step 5: Commit only the implementation and test**

```powershell
git add -- apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "fix: balance check-in location recovery actions"
```

