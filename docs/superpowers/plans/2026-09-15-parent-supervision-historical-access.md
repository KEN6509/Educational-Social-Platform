# Parent Supervision Historical Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow a former parent to read Check-In and SOS records created while their relationship was active, without exposing later records or changing the unlink workflow.

**Architecture:** PostgreSQL RLS remains the authorization source. Safety-record select policies use each relationship's `linked_at` and `revoked_at` window; Flutter keeps its existing notification router and Parent-only Safety Records page.

**Tech Stack:** Supabase PostgreSQL/RLS, Flutter/Dart contract tests, Markdown deployment documentation.

---

### Task 1: Define the Historical Access Policy Contract

**Files:**
- Modify: `apps/mobile/test/parent_supervision_sql_test.dart`
- Test: `apps/mobile/test/parent_supervision_sql_test.dart`

- [ ] **Step 1: Write failing structural tests**

Add assertions that the complete migration, base schema, and focused upgrade all
contain relationship-window checks for Check-In, SOS, live-location, and event
reads, while screen-time and SOS writes remain active-link-only.

```dart
expect(sql, contains("link.linked_at <= check_ins.created_at"));
expect(sql, contains("check_ins.created_at <= link.revoked_at"));
expect(sql, contains("link.linked_at <= sos_alerts.created_at"));
expect(sql, contains("sos_alerts.created_at <= link.revoked_at"));
expect(sql, contains("link.status = 'active'"));
expect(sql, contains("link.status = 'revoked'"));
```

- [ ] **Step 2: Verify RED**

Run from `apps/mobile`:

```powershell
flutter test test/parent_supervision_sql_test.dart --no-pub --reporter expanded
```

Expected: FAIL because the existing policies require only active links and the
focused upgrade does not exist.

### Task 2: Implement Time-Window RLS

**Files:**
- Create: `supabase/parent_supervision_history_access.sql`
- Modify: `supabase/parent_supervision.sql`
- Modify: `supabase/schema.sql`
- Test: `apps/mobile/test/parent_supervision_sql_test.dart`

- [ ] **Step 1: Add the focused rerunnable migration**

Replace only the four safety-record select policies. Each parent branch uses:

```sql
link.parent_id = auth.uid()
and link.child_id = <record child id>
and link.linked_at is not null
and link.linked_at <= <record created_at>
and (
  link.status = 'active'
  or (
    link.status = 'revoked'
    and link.revoked_at is not null
    and <record created_at> <= link.revoked_at
  )
)
```

For `sos_live_locations` and `sos_events`, join their `sos_alerts` row and use
the alert's `child_id` and `created_at`. Keep direct owner checks unchanged.

- [ ] **Step 2: Keep canonical SQL aligned**

Apply the same four policy definitions to `parent_supervision.sql` and
`schema.sql`. Do not change screen-time policies or any insert/update RPC.

- [ ] **Step 3: Verify GREEN**

Run:

```powershell
cd apps/mobile
flutter test test/parent_supervision_sql_test.dart --no-pub --reporter expanded
```

Expected: PASS.

### Task 3: Document Setup and Final Status

**Files:**
- Modify: `docs/setup.md`
- Modify: `supabase/README.md`
- Modify: `Project_Overview.md`

- [ ] **Step 1: Document migration order**

Add `supabase/parent_supervision_history_access.sql` after the complete Parent
Supervision script for existing projects. State that it is rerunnable and
policy-only.

- [ ] **Step 2: Update the project status**

Record the implemented time-window rule, remove former-link history from the
unresolved SRS list, and state that password reauthentication is intentionally
not part of the current unlink flow.

- [ ] **Step 3: Run complete verification**

```powershell
cd apps/mobile
dart format --output=none --set-exit-if-changed test/parent_supervision_sql_test.dart
flutter test --no-pub --reporter compact
flutter analyze --no-pub

cd ../..
git diff --check
```

Expected: all tests pass, analyzer reports no issues, formatting is unchanged,
and `git diff --check` reports no errors.

- [ ] **Step 4: Commit the implementation**

```powershell
git add -- apps/mobile/test/parent_supervision_sql_test.dart supabase/parent_supervision_history_access.sql supabase/parent_supervision.sql supabase/schema.sql docs/setup.md supabase/README.md Project_Overview.md
git commit -m "feat: preserve supervision record history"
```

### Task 4: Manual Supabase Acceptance

After merge, run `supabase/parent_supervision_history_access.sql` in Supabase.
Verify with two accounts:

1. Create Check-In and SOS records while the relationship is active.
2. Complete the two-party unlink.
3. Confirm the former parent can open those records through existing
   Supervision notifications.
4. Confirm a record created after unlink is inaccessible to the former parent.
5. Re-establish any Parent role and confirm the Safety Records page includes
   only records from valid current or former relationship windows.
