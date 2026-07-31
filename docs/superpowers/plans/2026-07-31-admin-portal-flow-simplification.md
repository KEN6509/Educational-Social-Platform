# Admin Portal Flow Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify report casework to one pending state, improve Users and Reports post evidence, remove out-of-scope Users actions, and present AI-Flagged Content as a complete-looking workflow while preserving its replaceable local adapter.

**Architecture:** Keep the existing React split-pane portal and Express/Supabase boundaries. Enforce administrator exclusion and the reduced report contract in the repository/API, reuse `PostDetailModal` for post evidence from both Users and Reports, isolate carousel/media state inside their focused components, and render report reasons through a dedicated Recharts component. Commit but do not execute the destructive Supabase migration against any remote project without separate approval.

**Tech Stack:** React 18, TypeScript, Vite, Vitest/Testing Library, Recharts, Express, Zod, Supabase/PostgreSQL, Flutter/Dart tests, PowerShell.

---

## Working rules

- [ ] Run every command directly in the user's PowerShell environment, never in the sandbox.
- [ ] Use test-first cycles: add one focused failing assertion, run it, implement the smallest change, rerun it.
- [ ] Preserve unrelated user changes in the working tree.
- [ ] Do not apply `supabase/report_flow_simplification.sql` to a remote Supabase project in this plan.
- [ ] Keep the report review threshold controlled by `REPORT_REVIEW_THRESHOLD`; its local testing value remains `1`.
- [ ] Keep account-suspension API/RPC foundations even though the Users UI no longer exposes them.

## Task 1: Lock the simplified report database contract

**Files:**

- Create: `supabase/report_flow_simplification.sql`
- Modify: `supabase/schema.sql`
- Modify: `supabase/admin_portal.sql`
- Modify: `services/api/src/admin/adminSql.test.ts`

- [ ] **Step 1: Add failing SQL contract tests**

Extend `adminSql.test.ts` to load all three SQL files and assert:

```ts
assert.match(schemaSql, /create type public\.report_status as enum \('pending_review', 'resolved', 'dismissed'\)/);
assert.match(schemaSql, /status public\.report_status not null default 'pending_review'/);
assert.doesNotMatch(schemaSql, /\bdescription text\b/);
assert.match(adminSql, /and status = 'pending_review'/);
assert.doesNotMatch(adminSql, /status in \('open', 'reviewing'\)/);
assert.match(migrationSql, /update public\.reports\s+set status = 'pending_review'/s);
assert.match(migrationSql, /drop column if exists description/);
assert.match(migrationSql, /where reporter_id is not null\s+and status = 'pending_review'/s);
```

Also assert that the migration retains `resolved` and `dismissed`, recreates `decide_report_case`, and contains no live connection command such as `supabase db push`.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test -- src/admin/adminSql.test.ts
```

Expected: failure because the old enum/default/description and unresolved predicates remain, and the migration file does not exist.

- [ ] **Step 3: Update the base schema and reusable admin SQL**

Use this base domain:

```sql
create type public.report_status as enum (
  'pending_review',
  'resolved',
  'dismissed'
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  target_type text not null check (target_type in ('post', 'comment', 'user')),
  target_id uuid not null,
  reason text not null check (char_length(reason) between 3 and 120),
  status public.report_status not null default 'pending_review',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Change every unresolved predicate in `admin_portal.sql` to `status = 'pending_review'`. Preserve the existing decision mapping:

```sql
v_new_report_status := case
  when p_decision = 'retain' then 'dismissed'::public.report_status
  else 'resolved'::public.report_status
end;
```

- [ ] **Step 4: Add the idempotent incremental migration**

The migration must perform this order inside a transaction:

```sql
begin;

drop index if exists public.reports_one_unresolved_per_reporter_target;
drop function if exists public.decide_report_case(text, uuid, text, text);

alter table public.reports alter column status drop default;
alter table public.reports
  alter column status type text using status::text;

update public.reports
set status = 'pending_review'
where status in ('open', 'reviewing');

drop type if exists public.report_status;
create type public.report_status as enum (
  'pending_review',
  'resolved',
  'dismissed'
);

alter table public.reports
  alter column status type public.report_status
  using status::public.report_status;
alter table public.reports
  alter column status set default 'pending_review';
alter table public.reports
  drop column if exists description;

create unique index reports_one_unresolved_per_reporter_target
on public.reports (reporter_id, target_type, target_id)
where reporter_id is not null
  and status = 'pending_review';
```

Append the complete updated `decide_report_case` function and its revoke/grant statements from `admin_portal.sql`, then `commit;`. Do not use `\i`, remote URLs, credentials, or CLI deployment commands in the migration.

- [ ] **Step 5: Run SQL tests and inspect the diff**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test -- src/admin/adminSql.test.ts
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git diff --check -- supabase/schema.sql supabase/admin_portal.sql supabase/report_flow_simplification.sql services/api/src/admin/adminSql.test.ts
```

Expected: SQL tests pass and `git diff --check` prints nothing.

- [ ] **Step 6: Commit the database contract**

```powershell
git add -- supabase/schema.sql supabase/admin_portal.sql supabase/report_flow_simplification.sql services/api/src/admin/adminSql.test.ts
git commit -m "refactor: simplify report database lifecycle"
```

## Task 2: Simplify API report types and exclude administrators

**Files:**

- Modify: `services/api/src/admin/adminSchemas.ts`
- Modify: `services/api/src/admin/adminTypes.ts`
- Modify: `services/api/src/admin/adminService.ts`
- Modify: `services/api/src/admin/adminRepository.ts`
- Modify: `services/api/src/admin/adminService.test.ts`
- Modify: `services/api/src/admin/adminRouter.test.ts`
- Modify: `services/api/src/admin/adminPostViews.test.ts`
- Create: `services/api/src/admin/adminRepository.test.ts`

- [ ] **Step 1: Rewrite fixtures and add failing contract assertions**

Use the new domain in all report fixtures:

```ts
export type ReportStatus = 'pending_review' | 'resolved' | 'dismissed';
```

Add schema assertions:

```ts
assert.equal(reportStatusSchema.safeParse('pending_review').success, true);
assert.equal(reportStatusSchema.safeParse('open').success, false);
assert.equal(reportStatusSchema.safeParse('reviewing').success, false);
assert.equal(reportCaseListQuerySchema.parse({}).status, 'pending_review');
```

Remove `description` from `ReportCaseRow` and report-history fixtures. In `adminRepository.test.ts`, use a minimal thenable Supabase query-builder fake that records `.eq` calls and filters its profile rows when awaited. Seed one administrator and one member, call `listUsers`, then assert:

```ts
assert.deepEqual(eqCalls, [['is_admin', false]]);
assert.deepEqual(result.items.map((item) => item.id), ['member-1']);
assert.equal(result.total, 1);
```

- [ ] **Step 2: Run focused API tests and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test -- src/admin/adminService.test.ts src/admin/adminRouter.test.ts src/admin/adminPostViews.test.ts src/admin/adminRepository.test.ts
```

Expected: failures for the old report status/default/description shape and missing administrator filter.

- [ ] **Step 3: Update validation and service logic**

Set:

```ts
export const reportStatusSchema = z.enum([
  'pending_review',
  'resolved',
  'dismissed',
]);

export const reportCaseListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  status: reportStatusSchema.default('pending_review'),
  targetType: reportTargetTypeSchema.optional(),
});
```

Overview grouping counts only cases whose grouped status contains `pending_review` and whose unique reporter count reaches `reportReviewThreshold`.

- [ ] **Step 4: Update repository reads and mappings**

Apply administrator exclusion at the database boundary:

```ts
let request = client
  .from('profiles')
  .select(profileSelect, { count: 'exact' })
  .eq('is_admin', false)
  .range(from, to);
```

Change overview unresolved reports to `.eq('status', 'pending_review')`. Remove `description` from every report select string, raw row type, and mapped history result. Keep `reason`, `reporter_id`, review fields, and resolution notes.

- [ ] **Step 5: Run the complete API suite and typecheck**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
npm run typecheck
```

Expected: all API tests pass and TypeScript reports no errors.

- [ ] **Step 6: Commit the API contract**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- services/api/src/admin
git commit -m "refactor: enforce pending report cases"
```

## Task 3: Remove report descriptions from mobile submission

**Files:**

- Modify: `apps/mobile/lib/src/features/posts/data/posts_repository.dart`
- Modify: `apps/mobile/test/posts_repository_test.dart`

- [ ] **Step 1: Add a failing reason-only insertion test**

Follow the existing repository source-contract test style. Slice from `Future<void> createReport` to `Future<void> createPost`, then assert:

```dart
final source = File('lib/src/features/posts/data/posts_repository.dart')
    .readAsStringSync();
final start = source.indexOf('Future<void> createReport');
final end = source.indexOf('Future<void> createPost');
final createReportSource = source.substring(start, end);

expect(createReportSource, contains(".from('reports').insert"));
expect(createReportSource, contains("'reason': reason"));
expect(createReportSource, isNot(contains('description')));
```

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\mobile'
flutter test test/posts_repository_test.dart
```

Expected: the old method signature or inserted map still includes optional description support.

- [ ] **Step 3: Make submission reason-only**

Implement this signature and insert shape:

```dart
Future<void> createReport({
  required String targetType,
  required String targetId,
  required String reason,
}) async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) {
    throw const AuthException('You need to log in to report content.');
  }

  await _client.from('reports').insert({
    'reporter_id': userId,
    'target_type': targetType,
    'target_id': targetId,
    'reason': reason,
  });
}
```

- [ ] **Step 4: Verify and commit**

```powershell
dart format lib/src/features/posts/data/posts_repository.dart test/posts_repository_test.dart
flutter test test/posts_repository_test.dart
flutter analyze
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/mobile/lib/src/features/posts/data/posts_repository.dart apps/mobile/test/posts_repository_test.dart
git commit -m "refactor: submit reason-only reports"
```

Expected: focused test and analyzer pass.

## Task 4: Add the accessible report-reason chart

**Files:**

- Modify: `apps/admin/package.json`
- Modify: `apps/admin/package-lock.json`
- Create: `apps/admin/src/features/reports/ReportReasonChart.tsx`
- Create: `apps/admin/src/features/reports/ReportReasonChart.test.tsx`

- [ ] **Step 1: Install the maintained chart dependency**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm install recharts
```

Expected: `recharts` appears in dependencies and the Admin lockfile changes.

- [ ] **Step 2: Add failing chart tests**

Test a seven-report example and assert visible semantic evidence:

```ts
expect(screen.getByText('7 total reports')).toBeVisible();
expect(screen.getByText('7 unique reporters')).toBeVisible();
expect(screen.getByText('Bullying or harassment')).toBeVisible();
expect(screen.getByText('4 · 57%')).toBeVisible();
expect(screen.getByText('Spam')).toBeVisible();
expect(screen.getByText('3 · 43%')).toBeVisible();
expect(screen.getByRole('img', { name: 'Report reasons' })).toBeVisible();
```

Add a zero-row case asserting `No report reasons available.` and no `NaN`/`Infinity` text.

- [ ] **Step 3: Run the focused test and confirm RED**

```powershell
npm test -- src/features/reports/ReportReasonChart.test.tsx
```

Expected: failure because the component does not exist.

- [ ] **Step 4: Implement the full-width horizontal evidence component**

`ReportReasonChart` accepts only:

```ts
type Props = {
  totalReports: number;
  uniqueReporters: number;
  reasonCounts: Array<{ reason: string; count: number }>;
};
```

Use stable colours selected by array index, a `PieChart`/`Pie`/`Cell` from Recharts, and text legend entries computed with:

```ts
const percentage = totalReports === 0
  ? 0
  : Math.round((item.count / totalReports) * 100);
```

The outer card uses a desktop grid such as `lg:grid-cols-[14rem_16rem_minmax(0,1fr)]` and stacks in source order on narrow screens. Give the chart wrapper `role="img"` and `aria-label="Report reasons"`; keep every reason/count/percentage in ordinary readable text.

- [ ] **Step 5: Verify and commit**

```powershell
npm test -- src/features/reports/ReportReasonChart.test.tsx
npm run typecheck
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/package.json apps/admin/package-lock.json apps/admin/src/features/reports/ReportReasonChart.tsx apps/admin/src/features/reports/ReportReasonChart.test.tsx
git commit -m "feat: visualize report reasons"
```

## Task 5: Rework Reports tabs, evidence, and shared post viewing

**Files:**

- Modify: `apps/admin/src/types/admin.ts`
- Modify: `apps/admin/src/components/casework/StatusBadge.tsx`
- Modify: `apps/admin/src/features/reports/ReportsPage.tsx`
- Modify: `apps/admin/src/features/reports/ReportCaseDetail.tsx`
- Modify: `apps/admin/src/features/reports/ReportsPage.test.tsx`
- Reuse: `apps/admin/src/features/users/PostDetailModal.tsx`

- [ ] **Step 1: Rewrite report fixtures and add failing UI tests**

Use `pending_review` in summary/detail fixtures and delete report descriptions. Assert:

```ts
expect(screen.getByRole('tab', { name: 'Pending Review' })).toBeVisible();
expect(screen.queryByRole('tab', { name: 'Reviewing' })).not.toBeInTheDocument();
expect(screen.getByRole('tab', { name: 'Resolved' })).toBeVisible();
expect(screen.getByRole('tab', { name: 'Dismissed' })).toBeVisible();
expect(api.get).toHaveBeenCalledWith('/admin/report-cases', expect.objectContaining({
  status: 'pending_review',
}));
expect(screen.queryByText('Reporter context')).not.toBeInTheDocument();
```

For a post target, assert `View Post >` triggers `GET /admin/posts/post-1`, shows the shared loading shell, then renders full post metadata/comments. Add a rejected request case with `Try again`. For a comment target, assert its text remains inline and `View Post >` is absent.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/reports/ReportsPage.test.tsx
```

Expected: failures for the Reviewing tab, old inline post content, old evidence cards, and missing shared popup.

- [ ] **Step 3: Update Admin report types and status badge**

Set the summary status to:

```ts
status: 'pending_review' | 'resolved' | 'dismissed';
```

Delete `description` from the nested report history type. Replace `open`/`reviewing` label and tone entries with:

```ts
pending_review: 'Pending Review',
```

using the existing amber pending-review tone.

- [ ] **Step 4: Preserve the Reported Content container but switch its body**

Give `ReportCaseDetail` an optional `onViewPost` callback. Render:

```tsx
{reportCase.targetType === 'post' ? (
  <button
    className="mt-3 text-sm font-extrabold text-cyan-700 hover:text-cyan-900"
    onClick={onViewPost}
    type="button"
  >
    View Post &gt;
  </button>
) : (
  <p className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">
    {reportCase.content || reportCase.targetExcerpt}
  </p>
)}
```

Replace both existing evidence cards with:

```tsx
<ReportReasonChart
  reasonCounts={reportCase.reasonCounts}
  totalReports={reportCase.totalReports}
  uniqueReporters={reportCase.uniqueReporters}
/>
```

Preserve case header, owner, visibility, spacing, and decision section.

- [ ] **Step 5: Add lazy shared-modal state to ReportsPage**

Mirror the established Users loading/error/retry pattern with `AdminPostDetailView`, `postDetailOpen`, `postDetailLoading`, `postDetailError`, and `postDetailId`. Only provide `onViewPost` for a post case. Render the existing `PostDetailModal` after the Reports page and return focus to the `View Post >` trigger on close.

Keep decisions available only for `detail.status === 'pending_review'`; keep both confirmation dialogs and their consequence copy unchanged.

- [ ] **Step 6: Verify Reports and commit**

```powershell
npm test -- src/features/reports/ReportsPage.test.tsx src/features/reports/ReportReasonChart.test.tsx
npm run typecheck
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/types/admin.ts apps/admin/src/components/casework/StatusBadge.tsx apps/admin/src/features/reports
git commit -m "feat: simplify report review flow"
```

## Task 6: Make recent-post controls depend on real overflow

**Files:**

- Modify: `apps/admin/src/features/users/RecentPostsCarousel.tsx`
- Modify: `apps/admin/src/features/users/PostReview.test.tsx`

- [ ] **Step 1: Add failing overflow tests**

Provide controllable `scrollWidth`, `clientWidth`, and `scrollLeft` values in jsdom. Assert:

- fitting five cards render neither `Previous posts` nor `Next posts`;
- overflowing cards render both controls;
- Previous is disabled at the start and Next is disabled at the end;
- a `scroll` event updates boundaries;
- a mocked `ResizeObserver` recalculates fit/overflow;
- the cover image has `block h-28 w-full object-cover`.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/users/PostReview.test.tsx
```

Expected: controls are currently always rendered and boundary state is based on post index rather than the rail.

- [ ] **Step 3: Implement measured overflow and boundaries**

Replace `position` with:

```ts
const [hasOverflow, setHasOverflow] = useState(false);
const [canScrollPrevious, setCanScrollPrevious] = useState(false);
const [canScrollNext, setCanScrollNext] = useState(false);

const measure = useCallback(() => {
  const rail = railRef.current;
  if (!rail) return;
  const overflow = rail.scrollWidth > rail.clientWidth + 1;
  setHasOverflow(overflow);
  setCanScrollPrevious(overflow && rail.scrollLeft > 1);
  setCanScrollNext(
    overflow && rail.scrollLeft + rail.clientWidth < rail.scrollWidth - 1,
  );
}, []);
```

Call `measure` after `recentPosts` changes, on rail scroll, and from `ResizeObserver`; fall back to a window `resize` listener when `ResizeObserver` is unavailable. Render both side controls only when `hasOverflow`. Scroll by one measured card width plus gap and let the subsequent scroll event update boundaries.

- [ ] **Step 4: Verify and commit**

```powershell
npm test -- src/features/users/PostReview.test.tsx
npm run typecheck
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/features/users/RecentPostsCarousel.tsx apps/admin/src/features/users/PostReview.test.tsx
git commit -m "feat: show post controls only on overflow"
```

## Task 7: Replace thumbnails with complete-image navigation

**Files:**

- Modify: `apps/admin/src/features/users/PostDetailModal.tsx`
- Modify: `apps/admin/src/features/users/PostReview.test.tsx`

- [ ] **Step 1: Add failing media navigation tests**

For a three-image post, assert Previous/Next image buttons, three labelled dot buttons, the active dot state, and `object-contain` on the displayed image. Click Next, Previous, and dot 3 and assert the image alt text changes. For a single-image post assert no side controls and no dots. Retain existing comments/replies, Escape, focus-trap, loading, retry, and no-image assertions.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/users/PostReview.test.tsx
```

Expected: thumbnails exist and side/dot controls do not.

- [ ] **Step 3: Implement side controls and bottom dots**

Keep the media wrapper relative. For multiple images render circular `Previous image` and `Next image` buttons at the left/right edges, disabled at index `0` and `images.length - 1`. Render dots at the bottom centre:

```tsx
<button
  aria-label={`Show image ${index + 1}`}
  aria-current={selectedImage === index ? 'true' : undefined}
  className={selectedImage === index ? activeDotClass : inactiveDotClass}
  onClick={() => setSelectedImage(index)}
  type="button"
/>
```

Delete the thumbnail rail. Keep the selected media class `h-full max-h-full w-full object-contain` so the complete source image is visible.

- [ ] **Step 4: Verify and commit**

```powershell
npm test -- src/features/users/PostReview.test.tsx src/components/casework/FullScreenDialog.test.tsx
npm run typecheck
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/features/users/PostDetailModal.tsx apps/admin/src/features/users/PostReview.test.tsx
git commit -m "feat: add complete post image navigation"
```

## Task 8: Remove suspension actions from Users while keeping creator confirmation

**Files:**

- Modify: `apps/admin/src/App.tsx`
- Modify: `apps/admin/src/features/users/UsersPage.tsx`
- Modify: `apps/admin/src/features/users/UsersPage.test.tsx`

- [ ] **Step 1: Add failing scope tests**

Assert the selected user detail has no `Suspend account`, `Reactivate account`, or self-suspension warning. Assert `Remove creator`/`Assign creator` remains, still requires a 10-character reason, opens the appropriate confirmation, and only posts to `/admin/users/:id/creator-status` after confirmation.

The list fixture must contain members/creators only; add a defensive assertion that no fixture row has `isAdmin: true`, while API repository tests from Task 2 prove enforcement.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/users/UsersPage.test.tsx
```

Expected: the current Account decision panel exposes suspension/reactivation.

- [ ] **Step 3: Narrow Users decisions to creator status**

Replace the decision union with:

```ts
type Decision = { nextValue: boolean };
```

Remove the `currentUserId` prop from `UsersPage` and its `App.tsx` call site. Remove `isSelf`, `accountButton`, the account branch in `confirmDecision`, the warning, and danger action props. Configure the panel as:

```tsx
<DecisionPanel
  helperText="Creator changes are audited and the member is notified."
  isSubmitting={submitting}
  onPrimary={() => setDecision({ nextValue: !detail.isContentCreator })}
  onReasonChange={setReason}
  primaryLabel={creatorButton}
  reason={reason}
  title="Creator decision"
/>
```

Keep confirmation wording for assignment/removal and keep the underlying account-status Admin API untouched.

- [ ] **Step 4: Verify and commit**

```powershell
npm test -- src/features/users/UsersPage.test.tsx src/features/users/PostReview.test.tsx
npm run typecheck
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/App.tsx apps/admin/src/features/users/UsersPage.tsx apps/admin/src/features/users/UsersPage.test.tsx
git commit -m "refactor: focus users portal on creator review"
```

## Task 9: Present AI-Flagged Content without implementation disclaimers

**Files:**

- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx`
- Preserve: `apps/admin/src/features/aiFlagged/aiFlaggedMockAdapter.ts`
- Preserve: `apps/admin/src/features/aiFlagged/aiFlaggedMockData.ts`

- [ ] **Step 1: Rewrite tests around production-facing behavior**

Assert the page does not visibly contain case-insensitive matches for `mock`, `preview`, `temporary`, `future`, `deferred`, `not implemented`, `not connected`, or `saved locally`. Assert queue/detail scores/statuses still render. For each decision action, assert no data/status change occurs before confirmation and the change occurs only after Confirm.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/aiFlagged/AiFlaggedContentPage.test.tsx
```

Expected: existing Preview/Gemini-not-connected/local-only wording violates the approved product UI.

- [ ] **Step 3: Replace only visible copy**

Use normal workflow labels such as:

```text
AI-Flagged Content
Review content identified for moderation.
Risk score
Flag evidence
Moderation decision
Decision saved.
Approve content?
Remove content?
```

Delete the Preview badge and disclaimer card. Preserve the existing isolated data adapter, queue states, scoring fields, local state transitions, confirmation popup, and consequence text—changing implementation-commentary wording only.

- [ ] **Step 4: Verify and commit**

```powershell
npm test -- src/features/aiFlagged/AiFlaggedContentPage.test.tsx
npm run typecheck
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx
git commit -m "refactor: present ai moderation workflow"
```

## Task 10: Update documentation and run full acceptance verification

**Files:**

- Modify: `Project_Overview.md`
- Modify: `docs/setup.md`
- Modify: `supabase/README.md`
- Verify: all files changed by Tasks 1-9

- [ ] **Step 1: Update the canonical project handoff**

Document these exact boundaries:

- report status is `pending_review`, `resolved`, or `dismissed`;
- report submission stores a reason and no description;
- the committed migration is manual and has not been applied remotely;
- administrator profiles are excluded from the Users API list;
- suspension APIs remain, but the Users portal exposes creator decisions only;
- recent post arrows are conditional on overflow and cards use cover media;
- the shared post modal uses complete-image side/dot navigation and is reused by Reports;
- Reports uses a pie chart/legend evidence card and post-only `View Post >`;
- AI-Flagged Content has production-facing UI wording, while Gemini and the real AI queue remain deferred;
- every Codex command/test must be run directly in PowerShell, never in the sandbox.

Update setup/SQL ordering to place `report_flow_simplification.sql` after the existing report/admin foundations for an already-provisioned database, while fresh projects use the updated base scripts.

- [ ] **Step 2: Run documentation and stale-contract scans**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git diff --check
rg -n "status in \('open', 'reviewing'\)|default 'open'|description text|Reporter context|Preview data|saved locally" services/api/src apps/admin/src apps/mobile/lib supabase/schema.sql supabase/admin_portal.sql supabase/report_flow_simplification.sql Project_Overview.md docs/setup.md supabase/README.md
```

Expected: no stale report-contract/UI-disclaimer matches. Unrelated SOS `open` statuses and historical design/plan documents are outside this scan.

- [ ] **Step 3: Run all automated verification directly in PowerShell**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
npm run typecheck
npm run build

Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test
npm run typecheck
npm run build

Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\mobile'
flutter test
flutter analyze
```

Expected: every test passes, both TypeScript projects typecheck/build, and Flutter reports no analyzer issues.

- [ ] **Step 4: Perform desktop and narrow browser acceptance**

Start the API/Admin applications directly from PowerShell and verify all nine browser acceptance points from the approved design:

1. carousel controls hidden on fit and shown on overflow;
2. edge-to-edge recent cover images;
3. complete-image Post Detail side controls/dots;
4. no admin rows or suspension action;
5. only Pending Review/Resolved/Dismissed report tabs;
6. post-only `View Post >` opens shared modal;
7. horizontal desktop and stacked narrow report chart card;
8. confirmation before creator/report/AI decisions;
9. no implementation-status wording on AI-Flagged Content.

Capture any browser console errors. Do not mutate remote Supabase data during this check.

- [ ] **Step 5: Review the complete diff against the approved spec**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git status --short
git diff --stat
git diff --check
```

Confirm there are no unfinished implementation markers, no remote migration execution, no Gemini integration, no account-suspension backend deletion, and no unrelated portal redesign.

- [ ] **Step 6: Commit documentation and final integration state**

```powershell
git add -- Project_Overview.md docs/setup.md supabase/README.md
git commit -m "docs: record simplified admin review flow"
git status --short
```

Expected: the worktree is clean. Do not create the requested `Admin Portal - before AI-integration` milestone commit here unless the user separately confirms that all pre-AI Admin Portal work is ready to be sealed into that exact milestone.
