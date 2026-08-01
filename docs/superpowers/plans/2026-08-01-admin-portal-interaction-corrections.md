# Admin Portal Interaction Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Admin Portal decision action respond with the approved conditional-reason and confirmation flow, preserve notification/audit guarantees, remove AI tab counts, and correct recent-card and Post Detail image presentation.

**Architecture:** Extend the existing shared `DecisionPanel` with per-action reason requirements while leaving confirmation and page submission ownership unchanged. Enforce the same conditional contracts in Zod and generate stable internal audit reasons in the service before existing Supabase RPC calls. Keep AI queue state local, add only the future real `pending` to `approved` post-notification trigger, and correct media sizing inside the two existing Users components.

**Tech Stack:** React 18, TypeScript, Tailwind CSS, Vite, Vitest/Testing Library, Express, Zod, Supabase/PostgreSQL, Node test runner, Flutter/Dart regression tests, PowerShell.

---

## Working rules

- [ ] Run every terminal command directly in the user's PowerShell environment outside the Codex sandbox.
- [ ] Work on the current `feature/parent-supervision` branch and preserve unrelated user changes.
- [ ] Follow one red-green cycle at a time: write a focused failing test, run it and inspect the intended failure, make the smallest production change, rerun the focused test, then commit.
- [ ] Keep confirmation popups on every administrator action.
- [ ] Do not apply any repository SQL file to a remote Supabase project without separate explicit approval.
- [ ] Do not connect the isolated AI queue adapter to Supabase or fabricate notifications for its temporary records.
- [ ] Keep Creator Requests unchanged and keep both Appeal actions reason-required.

## File map

- `apps/admin/src/components/casework/DecisionPanel.tsx`: shared per-action reason validation, inline feedback, and action dispatch.
- `apps/admin/src/components/casework/casework.test.tsx`: focused shared-component regression contract.
- `apps/admin/src/features/users/UsersPage.tsx`: Assign versus Remove creator reason policy and API payload.
- `apps/admin/src/features/reports/ReportsPage.tsx`: Retain versus Remove reason policy and API payload.
- `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`: Approve versus Reject reason policy and count-free tabs.
- `apps/admin/src/features/appeals/AppealsPage.tsx`: unchanged all-reason-required consumer, covered as regression evidence.
- `apps/admin/src/features/users/RecentPostsCarousel.tsx`: top-aligned flex card, edge-to-edge cover media, and hover clearance.
- `apps/admin/src/features/users/PostDetailModal.tsx`: media-stage-bounded contain image.
- `services/api/src/admin/adminSchemas.ts`: conditional creator/report reason validation.
- `services/api/src/admin/adminService.ts`: stable internal audit reasons for permitted blank inputs.
- `services/api/src/admin/adminTypes.ts`: retain normalized service/repository inputs with a required string reason.
- `supabase/chat.sql`: real post `pending` to `approved` publication notification trigger.
- `services/api/src/admin/adminSql.test.ts`: static SQL notification and no-notification contracts.
- `Project_Overview.md`, `docs/setup.md`, `supabase/README.md`: implementation status, database setup, notification, and verification documentation.

## Task 1: Make the shared decision panel validate per action

**Files:**

- Modify: `apps/admin/src/components/casework/DecisionPanel.tsx`
- Modify: `apps/admin/src/components/casework/casework.test.tsx`

- [ ] **Step 1: Replace the old disabled-button test with failing per-action tests**

Add one test for a reason-free primary action and a reason-required danger action:

```tsx
it('allows a blank optional reason but validates every supplied reason', async () => {
  const user = userEvent.setup();
  const onPrimary = vi.fn();
  const onDanger = vi.fn();
  const onReasonChange = vi.fn();

  const { rerender } = render(
    <DecisionPanel
      dangerLabel="Remove content"
      dangerRequiresReason
      isSubmitting={false}
      onDanger={onDanger}
      onPrimary={onPrimary}
      onReasonChange={onReasonChange}
      primaryLabel="Retain content"
      primaryRequiresReason={false}
      reason=""
    />,
  );

  await user.click(screen.getByRole('button', { name: 'Retain content' }));
  expect(onPrimary).toHaveBeenCalledOnce();

  rerender(
    <DecisionPanel
      dangerLabel="Remove content"
      dangerRequiresReason
      isSubmitting={false}
      onDanger={onDanger}
      onPrimary={onPrimary}
      onReasonChange={onReasonChange}
      primaryLabel="Retain content"
      primaryRequiresReason={false}
      reason="short"
    />,
  );
  await user.click(screen.getByRole('button', { name: 'Retain content' }));
  expect(onPrimary).toHaveBeenCalledOnce();
  expect(screen.getByRole('alert')).toBeVisible();

  await user.click(screen.getByRole('button', { name: 'Remove content' }));
  expect(onDanger).not.toHaveBeenCalled();
  expect(screen.getByRole('alert')).toHaveTextContent(
    'Enter a reason between 10 and 500 characters before choosing "Remove content".',
  );
  expect(screen.getByLabelText(/Decision reason/)).toHaveFocus();
});
```

Retain a separate default-policy assertion proving existing Appeals/Creator Requests behaviour:

```tsx
it('requires a valid reason for both actions by default', async () => {
  const user = userEvent.setup();
  const onPrimary = vi.fn();
  const onDanger = vi.fn();

  render(
    <DecisionPanel
      dangerLabel="Reject appeal"
      isSubmitting={false}
      onDanger={onDanger}
      onPrimary={onPrimary}
      onReasonChange={vi.fn()}
      primaryLabel="Approve appeal"
      reason="short"
    />,
  );

  await user.click(screen.getByRole('button', { name: 'Approve appeal' }));
  expect(onPrimary).not.toHaveBeenCalled();
  expect(screen.getByRole('alert')).toBeVisible();

  await user.click(screen.getByRole('button', { name: 'Reject appeal' }));
  expect(onDanger).not.toHaveBeenCalled();
});
```

- [ ] **Step 2: Run the shared component test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/components/casework/casework.test.tsx
```

Expected: TypeScript/React failures because `primaryRequiresReason` and `dangerRequiresReason` do not exist and the current invalid buttons are inert and disabled.

- [ ] **Step 3: Add conditional validation to `DecisionPanel`**

Extend `Props` without changing the default policy:

```ts
type Props = {
  reason: string;
  onReasonChange: (value: string) => void;
  primaryLabel: string;
  dangerLabel?: string;
  isSubmitting: boolean;
  onPrimary: () => void;
  onDanger?: () => void;
  title?: string;
  helperText?: string;
  dangerDisabled?: boolean;
  primaryRequiresReason?: boolean;
  dangerRequiresReason?: boolean;
};
```

Import `useRef` and `useState`. Add the new defaults to the existing destructuring:

```ts
primaryRequiresReason = true,
dangerRequiresReason = true,
```

Then use this exact validation boundary:

```tsx
const [validationError, setValidationError] = useState<string | null>(null);
const reasonRef = useRef<HTMLTextAreaElement>(null);
const reasonLength = reason.trim().length;

function runAction(
  label: string,
  requiresReason: boolean,
  action: () => void,
) {
  const missingRequiredReason = requiresReason && reasonLength === 0;
  const invalidSuppliedReason =
    reasonLength > 0 && (reasonLength < 10 || reasonLength > 500);
  if (missingRequiredReason || invalidSuppliedReason) {
    setValidationError(
      `Enter a reason between 10 and 500 characters before choosing "${label}".`,
    );
    reasonRef.current?.focus();
    return;
  }
  setValidationError(null);
  action();
}

const requirementLabel =
  primaryRequiresReason && (!dangerLabel || dangerRequiresReason)
    ? '(required)'
    : !primaryRequiresReason && dangerLabel && dangerRequiresReason
      ? `(required for ${dangerLabel})`
      : primaryRequiresReason && dangerLabel && !dangerRequiresReason
        ? `(required for ${primaryLabel})`
        : '(optional)';
```

Wire the textarea and error state as follows:

```tsx
Decision reason{' '}
<span className="font-medium text-slate-400">
  {requirementLabel}
</span>
<textarea
  aria-describedby={validationError ? 'decision-reason-error' : undefined}
  aria-invalid={validationError ? 'true' : undefined}
  className="mt-2 min-h-28 w-full resize-y rounded-lg border border-slate-300 px-3 py-3 text-sm font-normal leading-6 outline-none transition placeholder:text-slate-400 focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
  maxLength={500}
  onChange={(event) => {
    setValidationError(null);
    onReasonChange(event.target.value);
  }}
  placeholder="Provide a clear reason for your decision…"
  ref={reasonRef}
  value={reason}
/>
{validationError ? (
  <span
    className="mt-1 block text-sm font-semibold text-red-600"
    id="decision-reason-error"
    role="alert"
  >
    {validationError}
  </span>
) : null}
```

Keep both buttons enabled for validation feedback unless submitting or explicitly disabled, and dispatch through `runAction`:

```tsx
disabled={isSubmitting}
onClick={() => runAction(primaryLabel, primaryRequiresReason, onPrimary)}
```

```tsx
disabled={isSubmitting || dangerDisabled}
onClick={() =>
  runAction(dangerLabel, dangerRequiresReason, onDanger)
}
```

- [ ] **Step 4: Run the focused test and confirm GREEN**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/components/casework/casework.test.tsx
npm run typecheck
```

Expected: the shared tests pass and TypeScript reports no errors.

- [ ] **Step 5: Commit the shared interaction contract**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/components/casework/DecisionPanel.tsx apps/admin/src/components/casework/casework.test.tsx
git commit -m "fix: validate administrator reasons per action"
```

## Task 2: Wire the approved page-level decision matrix

**Files:**

- Modify: `apps/admin/src/features/users/UsersPage.tsx`
- Modify: `apps/admin/src/features/users/UsersPage.test.tsx`
- Modify: `apps/admin/src/features/reports/ReportsPage.tsx`
- Modify: `apps/admin/src/features/reports/ReportsPage.test.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx`
- Modify: `apps/admin/src/features/appeals/AppealsPage.test.tsx`

- [ ] **Step 1: Add failing Users tests for Assign and Remove creator**

Change the existing assignment test so it does not type a reason and asserts the blank payload after confirmation:

```tsx
await user.click(screen.getByRole('button', { name: 'Assign creator' }));
const dialog = screen.getByRole('dialog', { name: 'Assign creator access?' });
await user.click(
  within(dialog).getByRole('button', { name: 'Confirm assignment' }),
);
expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/creator-status', {
  isCreator: true,
  reason: '',
});
```

Allow the existing API helper to receive a selected detail fixture:

```tsx
function createApi(selectedDetail: UserDetailView = detail) {
  return {
    get: vi.fn(async (path: string) => {
      if (path === '/admin/users') {
        return {
          items: [{ ...userSummary, isContentCreator: selectedDetail.isContentCreator }],
          page: 1,
          pageSize: 20,
          total: 1,
        } satisfies PageResult<UserSummaryView>;
      }
      return selectedDetail;
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}
```

Add a creator fixture and prove removal gives visible validation before it can open confirmation:

```tsx
const api = createApi({ ...detail, isContentCreator: true });
render(<UsersPage api={api} />);
await screen.findByText('Science educator');

await user.click(screen.getByRole('button', { name: 'Remove creator' }));
expect(screen.queryByRole('dialog', { name: 'Remove creator access?' })).not.toBeInTheDocument();
expect(screen.getByRole('alert')).toHaveTextContent(
  'Enter a reason between 10 and 500 characters before choosing "Remove creator".',
);
```

- [ ] **Step 2: Add failing Reports tests for Retain and Remove**

Add the reason-free Retain path:

```tsx
await user.click(screen.getByRole('button', { name: 'Retain content' }));
const retainDialog = screen.getByRole('dialog', { name: 'Retain this content?' });
await user.click(
  within(retainDialog).getByRole('button', { name: 'Confirm retention' }),
);
expect(api.post).toHaveBeenCalledWith(
  '/admin/report-cases/post/post-1/decision',
  { decision: 'retain', reason: '' },
);
```

Before the existing valid Remove path, use these exact assertions, then enter the valid reason and retain the existing request assertion:

```tsx
await user.click(screen.getByRole('button', { name: 'Remove content' }));
expect(
  screen.queryByRole('dialog', { name: 'Remove this content?' }),
).not.toBeInTheDocument();
expect(screen.getByRole('alert')).toHaveTextContent(
  'Enter a reason between 10 and 500 characters before choosing "Remove content".',
);

await user.type(
  screen.getByLabelText(/Decision reason/),
  'The post contains unsafe health misinformation.',
);
await user.click(screen.getByRole('button', { name: 'Remove content' }));
expect(screen.getByRole('dialog', { name: 'Remove this content?' })).toBeVisible();
```

- [ ] **Step 3: Add failing AI and Appeals regression tests**

Revise the AI confirmation test to click Approve without entering a reason. Assert tab accessible names are exactly `Pending`, `Approved`, and `Rejected`, with no numeric text:

```tsx
expect(screen.getByRole('tab', { name: 'Pending' })).toHaveTextContent(/^Pending$/);
expect(screen.getByRole('tab', { name: 'Approved' })).toHaveTextContent(/^Approved$/);
expect(screen.getByRole('tab', { name: 'Rejected' })).toHaveTextContent(/^Rejected$/);

await user.click(screen.getByRole('button', { name: 'Approve content' }));
expect(screen.getByRole('dialog', { name: 'Approve content?' })).toBeVisible();
```

Add a fresh AI render that clicks Reject with an empty reason and asserts visible validation and no confirmation:

```tsx
it('requires a reason before rejecting content', async () => {
  const user = userEvent.setup();
  render(<AiFlaggedContentPage />);

  await user.click(screen.getByRole('button', { name: 'Reject content' }));
  expect(
    screen.queryByRole('dialog', { name: 'Reject content?' }),
  ).not.toBeInTheDocument();
  expect(screen.getByRole('alert')).toHaveTextContent(
    'Enter a reason between 10 and 500 characters before choosing "Reject content".',
  );
});
```

In `AppealsPage.test.tsx`, add a blank Approve click assertion proving the dialog remains closed and validation remains required:

```tsx
it('keeps both appeal decisions reason-required', async () => {
  const user = userEvent.setup();
  render(<AppealsPage api={createApi()} />);
  await screen.findByText('Rejected content');

  await user.click(screen.getByRole('button', { name: 'Approve appeal' }));
  expect(
    screen.queryByRole('dialog', { name: 'Approve this appeal?' }),
  ).not.toBeInTheDocument();
  expect(screen.getByRole('alert')).toHaveTextContent(
    'Enter a reason between 10 and 500 characters before choosing "Approve appeal".',
  );
});
```

- [ ] **Step 4: Run the four page tests and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/users/UsersPage.test.tsx src/features/reports/ReportsPage.test.tsx src/features/aiFlagged/AiFlaggedContentPage.test.tsx src/features/appeals/AppealsPage.test.tsx
```

Expected: Users Assign, Reports Retain, and AI Approve remain blocked; AI tabs still include counts.

- [ ] **Step 5: Wire Users, Reports, and AI to the shared policy**

In Users, preserve the one primary button and make its policy depend on the selected member's current creator state:

```tsx
<DecisionPanel
  helperText={
    detail.isContentCreator
      ? 'Removing creator access requires a reason and notifies the member.'
      : 'Assigning creator access is audited and automatically notifies the member.'
  }
  isSubmitting={submitting}
  onPrimary={() => setDecision({ nextValue: !detail.isContentCreator })}
  onReasonChange={setReason}
  primaryLabel={creatorButton}
  primaryRequiresReason={detail.isContentCreator}
  reason={reason}
  title="Creator decision"
/>
```

In Reports, set only Retain to reason-free:

```tsx
<DecisionPanel
  dangerLabel="Remove content"
  dangerRequiresReason
  helperText="Retaining keeps the content visible without notifying the author. Removing hides it, records the reason, and notifies the author."
  isSubmitting={submitting}
  onDanger={() => setDecision('remove')}
  onPrimary={() => setDecision('retain')}
  onReasonChange={setReason}
  primaryLabel="Retain content"
  primaryRequiresReason={false}
  reason={reason}
/>
```

In AI, remove every `count` property from the three `CaseworkTabs` items and apply the same positive/negative policy:

```tsx
items={[
  { id: 'pending', label: 'Pending' },
  { id: 'approved', label: 'Approved' },
  { id: 'rejected', label: 'Rejected' },
]}
```

```tsx
<DecisionPanel
  dangerLabel="Reject content"
  dangerRequiresReason
  helperText="Approval publishes eligible uncertain content. Rejection requires a clear moderation reason."
  isSubmitting={false}
  onDanger={() => setDecision('rejected')}
  onPrimary={() => setDecision('approved')}
  onReasonChange={setReason}
  primaryLabel="Approve content"
  primaryRequiresReason={false}
  reason={reason}
  title="Moderation decision"
/>
```

Do not change the Appeals or Creator Requests call sites; the shared defaults keep both actions reason-required.

- [ ] **Step 6: Run the focused Admin tests and confirm GREEN**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/components/casework/casework.test.tsx src/features/users/UsersPage.test.tsx src/features/reports/ReportsPage.test.tsx src/features/aiFlagged/AiFlaggedContentPage.test.tsx src/features/appeals/AppealsPage.test.tsx
npm run typecheck
```

Expected: all focused tests pass and no type errors are reported.

- [ ] **Step 7: Commit the page flow corrections**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/features/users/UsersPage.tsx apps/admin/src/features/users/UsersPage.test.tsx apps/admin/src/features/reports/ReportsPage.tsx apps/admin/src/features/reports/ReportsPage.test.tsx apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx apps/admin/src/features/appeals/AppealsPage.test.tsx
git commit -m "fix: activate administrator decision flows"
```

## Task 3: Enforce conditional reasons and stable audit text in the API

**Files:**

- Modify: `services/api/src/admin/adminSchemas.ts`
- Modify: `services/api/src/admin/adminService.ts`
- Modify: `services/api/src/admin/adminService.test.ts`
- Modify: `services/api/src/admin/adminRouter.test.ts`

- [ ] **Step 1: Add failing schema tests**

Import `reportDecisionSchema` and `userCreatorStatusSchema` into `adminService.test.ts`, then assert the complete boundary:

```ts
test('creator and report decisions require reasons only for punitive actions', () => {
  assert.deepEqual(userCreatorStatusSchema.parse({ isCreator: true }), {
    isCreator: true,
    reason: '',
  });
  assert.equal(
    userCreatorStatusSchema.safeParse({ isCreator: false, reason: '' }).success,
    false,
  );
  assert.deepEqual(reportDecisionSchema.parse({ decision: 'retain' }), {
    decision: 'retain',
    reason: '',
  });
  assert.equal(
    reportDecisionSchema.safeParse({ decision: 'remove', reason: 'short' }).success,
    false,
  );
  assert.equal(
    reportDecisionSchema.safeParse({
      decision: 'remove',
      reason: 'The reported content violates the community rules.',
    }).success,
    true,
  );
});
```

Also assert a non-empty positive-action reason shorter than 10 characters is rejected, preventing a value that the SQL RPC would refuse.

- [ ] **Step 2: Add failing service audit-reason tests**

Capture repository inputs and assert exact normalized values:

```ts
test('reason-free positive decisions receive stable internal audit reasons', async () => {
  const creatorInputs: UserCreatorStatusInput[] = [];
  const reportInputs: ReportCaseDecisionInput[] = [];
  const repository = createRepository({
    setUserCreatorStatus: async (_userId, input) => {
      creatorInputs.push(input);
    },
    decideReportCase: async (_targetType, _targetId, input) => {
      reportInputs.push(input);
    },
  });
  const service = createAdminService(repository, 1);

  await service.setUserCreatorStatus('user-1', {
    isCreator: true,
    reason: '',
  });
  await service.decideReportCase('post', 'post-1', {
    decision: 'retain',
    reason: '',
  });

  assert.equal(
    creatorInputs[0]?.reason,
    'Creator status assigned by an administrator.',
  );
  assert.equal(
    reportInputs[0]?.reason,
    'Reported content retained by an administrator.',
  );
});
```

Add a second test proving valid Remove and creator-removal reasons are trimmed and preserved exactly.

- [ ] **Step 3: Add failing router tests for omitted positive reasons**

Add `ReportCaseDecisionInput` and `UserCreatorStatusInput` to the existing `adminTypes.js` type import. Use `createDependencies` with service spies, then build the authenticated test app exactly as the existing router tests do:

```ts
const creatorInputs: UserCreatorStatusInput[] = [];
const reportInputs: ReportCaseDecisionInput[] = [];
const dependencies = createDependencies(async () => expectedOverview, {
  setUserCreatorStatus: async (_userId, input) => {
    creatorInputs.push(input);
  },
  decideReportCase: async (_targetType, _targetId, input) => {
    reportInputs.push(input);
  },
});
const app = createApp(dependencies);

await request(app)
  .post('/admin/users/user-1/creator-status')
  .set('Authorization', 'Bearer valid-token')
  .send({ isCreator: true })
  .expect(204);

await request(app)
  .post('/admin/report-cases/post/post-1/decision')
  .set('Authorization', 'Bearer valid-token')
  .send({ decision: 'retain' })
  .expect(204);

assert.deepEqual(creatorInputs, [{ isCreator: true, reason: '' }]);
assert.deepEqual(reportInputs, [{ decision: 'retain', reason: '' }]);
```

Add corresponding 400 assertions for `isCreator: false` and `decision: 'remove'` without reasons:

```ts
await request(app)
  .post('/admin/users/user-1/creator-status')
  .set('Authorization', 'Bearer valid-token')
  .send({ isCreator: false })
  .expect(400);

await request(app)
  .post('/admin/report-cases/post/post-1/decision')
  .set('Authorization', 'Bearer valid-token')
  .send({ decision: 'remove' })
  .expect(400);
```

- [ ] **Step 4: Run API tests and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
```

Expected: the reason-free positive payloads fail the current common `reasonSchema`, and blank reasons reach the repository unchanged in direct service tests.

- [ ] **Step 5: Implement the conditional Zod schemas**

Add one optional-but-valid-when-present schema:

```ts
const optionalDecisionReasonSchema = z
  .string()
  .trim()
  .max(500)
  .refine(
    (value) => value.length === 0 || value.length >= 10,
    'Reason must be empty or contain at least 10 characters.',
  )
  .optional()
  .default('');
```

Replace the two common objects with discriminated unions:

```ts
export const userCreatorStatusSchema = z.discriminatedUnion('isCreator', [
  z.object({
    isCreator: z.literal(true),
    reason: optionalDecisionReasonSchema,
  }),
  z.object({
    isCreator: z.literal(false),
    reason: reasonSchema,
  }),
]);

export const reportDecisionSchema = z.discriminatedUnion('decision', [
  z.object({
    decision: z.literal('retain'),
    reason: optionalDecisionReasonSchema,
  }),
  z.object({
    decision: z.literal('remove'),
    reason: reasonSchema,
  }),
]);
```

Leave `appealDecisionSchema`, `creatorRequestDecisionSchema`, and account status validation on `reasonSchema`.

- [ ] **Step 6: Generate stable audit reasons in the service**

Add module constants near the service factory:

```ts
const CREATOR_ASSIGN_AUDIT_REASON =
  'Creator status assigned by an administrator.';
const REPORT_RETAIN_AUDIT_REASON =
  'Reported content retained by an administrator.';
```

Normalize creator decisions before the repository boundary:

```ts
const reason = input.reason.trim();
await repository.setUserCreatorStatus(userId, {
  ...input,
  reason:
    input.isCreator && reason.length === 0
      ? CREATOR_ASSIGN_AUDIT_REASON
      : reason,
});
```

Normalize report decisions in the same way:

```ts
const reason = input.reason.trim();
await repository.decideReportCase(targetType, targetId, {
  ...input,
  reason:
    input.decision === 'retain' && reason.length === 0
      ? REPORT_RETAIN_AUDIT_REASON
      : reason,
});
```

The normalized `reason` remains a required string in `UserCreatorStatusInput` and `ReportCaseDecisionInput`, so the repository and SQL RPC interfaces do not change.

- [ ] **Step 7: Run API tests and confirm GREEN**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
npm run typecheck
```

Expected: all API tests pass and the compiler reports no type errors.

- [ ] **Step 8: Commit API validation and audit normalization**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- services/api/src/admin/adminSchemas.ts services/api/src/admin/adminService.ts services/api/src/admin/adminService.test.ts services/api/src/admin/adminRouter.test.ts
git commit -m "fix: preserve audits for reason-free admin actions"
```

## Task 4: Add the real successful-publication notification foundation

**Files:**

- Modify: `supabase/chat.sql`
- Modify: `services/api/src/admin/adminSql.test.ts`
- Modify: `supabase/README.md`

- [ ] **Step 1: Add failing SQL notification-contract tests**

Load `chat.sql` in `adminSql.test.ts`:

```ts
const chatSql = readFileSync(
  new URL('../../../../supabase/chat.sql', import.meta.url),
  'utf8',
).toLowerCase();
```

Add these assertions:

```ts
test('creator, moderation, report, and appeal notification rules stay explicit', () => {
  assert.match(chatSql, /create or replace function public\.notify_content_creator_awarded/);
  assert.match(chatSql, /create or replace function public\.notify_post_rejected/);
  assert.match(chatSql, /create or replace function public\.notify_post_approved/);
  assert.match(
    chatSql,
    /old\.moderation_status = 'pending'[\s\S]*new\.moderation_status = 'approved'/,
  );
  assert.match(chatSql, /'template_type', 'post_approved'/);

  const reportFunction = sql.slice(
    sql.indexOf('create or replace function public.decide_report_case'),
    sql.indexOf('create or replace function public.decide_post_appeal'),
  );
  assert.match(
    reportFunction,
    /if p_decision = 'remove' then[\s\S]*perform public\.admin_portal_notify/,
  );
  assert.doesNotMatch(
    reportFunction,
    /if p_decision = 'retain' then[\s\S]*perform public\.admin_portal_notify/,
  );
});
```

- [ ] **Step 2: Run the SQL test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
```

Expected: failure because `notify_post_approved` and its trigger do not exist.

- [ ] **Step 3: Add an idempotent pending-to-approved notification trigger**

Add this focused function beside `notify_post_rejected` in `chat.sql`:

```sql
create or replace function public.notify_post_approved()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_name text;
begin
  if old.moderation_status = 'pending'
    and new.moderation_status = 'approved'
  then
    select p.name
    into v_author_name
    from public.profiles p
    where p.id = new.author_id;

    insert into public.notifications (
      user_id,
      type,
      post_id,
      title,
      body,
      action_type,
      action_payload
    )
    select
      new.author_id,
      'system',
      new.id,
      'Your post was published successfully',
      format(
        E'Hi %s,\n\nYour post “%s” passed moderation and was published successfully.',
        coalesce(v_author_name, 'CyanZone creator'),
        new.title
      ),
      'post_detail',
      jsonb_build_object(
        'template_type', 'post_approved',
        'post_title', new.title
      )
    where coalesce((
      select np.in_app_enabled and np.system_enabled
      from public.notification_preferences np
      where np.user_id = new.author_id
    ), true)
      and not exists (
        select 1
        from public.notifications existing
        where existing.user_id = new.author_id
          and existing.type = 'system'
          and existing.post_id = new.id
          and existing.action_payload->>'template_type' = 'post_approved'
      );
  end if;

  return new;
end;
$$;
```

Register it independently so repeated SQL execution is safe:

```sql
drop trigger if exists notify_post_approved_on_update on public.posts;
create trigger notify_post_approved_on_update
after update of moderation_status on public.posts
for each row execute function public.notify_post_approved();
```

The exact old-state check prevents approved Appeals (`rejected` to `approved`) from receiving the generic publication message in addition to the existing appeal-approved message.

- [ ] **Step 4: Document the third system-notification trigger**

Update `supabase/README.md` to state that `chat.sql` installs system triggers for creator badges, rejected posts, and posts moving specifically from Pending to Approved. State that the AI portal adapter remains local and therefore does not itself create database notifications.

- [ ] **Step 5: Run SQL/API tests and confirm GREEN**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git diff --check -- supabase/chat.sql supabase/README.md services/api/src/admin/adminSql.test.ts
```

Expected: all API/SQL contract tests pass and the diff check prints nothing.

- [ ] **Step 6: Commit the notification foundation**

```powershell
git add -- supabase/chat.sql supabase/README.md services/api/src/admin/adminSql.test.ts
git commit -m "feat: notify authors when uncertain posts publish"
```

## Task 5: Correct recent-card and Post Detail media geometry

**Files:**

- Modify: `apps/admin/src/features/users/RecentPostsCarousel.tsx`
- Modify: `apps/admin/src/features/users/PostDetailModal.tsx`
- Modify: `apps/admin/src/features/users/PostReview.test.tsx`

- [ ] **Step 1: Add failing recent-card geometry assertions**

Give the first card and its media wrapper testable structural contracts:

```tsx
const firstCard = screen.getByRole('button', { name: 'Open post Repair guide' });
expect(firstCard).toHaveClass('flex', 'flex-col', 'hover:-translate-y-0.5');
expect(screen.getByTestId('recent-post-media-post-1')).toHaveClass(
  'h-28',
  'w-full',
  'shrink-0',
  'overflow-hidden',
);
expect(
  document.querySelector('img[src="https://img.test/post-1.jpg"]'),
).toHaveClass('h-full', 'w-full', 'object-cover');
expect(screen.getByTestId('recent-posts-rail')).toHaveClass('pt-2');
```

- [ ] **Step 2: Add a failing media-stage containment assertion**

In the Post Detail test, assert both the stage and selected image geometry:

```tsx
expect(within(dialog).getByTestId('post-media-stage')).toHaveClass(
  'relative',
  'overflow-hidden',
  'bg-slate-900',
);
expect(
  within(dialog).getByRole('img', { name: 'Repair guide image 1' }),
).toHaveClass(
  'absolute',
  'inset-0',
  'h-full',
  'w-full',
  'object-contain',
);
```

- [ ] **Step 3: Run the focused media test and confirm RED**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/users/PostReview.test.tsx
```

Expected: failures for missing flex layout, media wrapper, rail clearance, dark stage, and absolute-fill image.

- [ ] **Step 4: Fix Recent Published Content card layout**

Set the rail clearance while preserving horizontal overflow and its controls:

```tsx
className="flex snap-x snap-mandatory gap-4 overflow-x-auto pb-2 pt-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
```

Use an explicit column card:

```tsx
className="group flex min-h-56 w-[280px] shrink-0 snap-start flex-col overflow-hidden rounded-xl border border-slate-200 bg-white text-left transition hover:-translate-y-0.5 hover:border-cyan-300 hover:shadow-lg focus:outline-none focus:ring-4 focus:ring-cyan-100"
```

Wrap image and fallback media in the same fixed region:

```tsx
<span
  className="block h-28 w-full shrink-0 overflow-hidden bg-slate-100"
  data-testid={`recent-post-media-${post.id}`}
>
  {post.coverImageUrl ? (
    <img
      alt=""
      className="block h-full w-full object-cover"
      src={post.coverImageUrl}
    />
  ) : (
    <span className="grid h-full w-full place-items-center text-slate-400">
      <FileText className="h-8 w-8" aria-hidden="true" />
    </span>
  )}
</span>
```

Make the information block fill the remaining card and anchor its footer:

```tsx
<span className="flex w-full flex-1 flex-col p-3.5">
```

```tsx
<span className="mt-auto flex items-center justify-between pt-3 text-xs font-semibold text-slate-400">
```

- [ ] **Step 5: Constrain Post Detail images to the stage**

Give the media stage a test identifier and neutral dark background:

```tsx
<div
  className="relative grid min-h-0 flex-1 place-items-center overflow-hidden rounded-xl bg-slate-900 shadow-sm"
  data-testid="post-media-stage"
>
```

Replace the selected image classes with absolute stage bounds:

```tsx
<img
  alt={`${post.title} image ${selectedImage + 1}`}
  className="absolute inset-0 h-full w-full object-contain"
  src={image.url}
/>
```

Keep the current arrows and dots after the image in DOM order so their positioned controls remain above it. Keep the text-only state centred and readable on the dark stage.

- [ ] **Step 6: Run focused tests and confirm GREEN**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test -- src/features/users/PostReview.test.tsx src/features/users/UsersPage.test.tsx src/features/reports/ReportsPage.test.tsx
npm run typecheck
```

Expected: media and consuming-page tests pass and TypeScript reports no errors.

- [ ] **Step 7: Commit the media corrections**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- apps/admin/src/features/users/RecentPostsCarousel.tsx apps/admin/src/features/users/PostDetailModal.tsx apps/admin/src/features/users/PostReview.test.tsx
git commit -m "fix: contain administrator post media"
```

## Task 6: Update project truth and run complete verification

**Files:**

- Modify: `Project_Overview.md`
- Modify: `docs/setup.md`
- Verify: all files changed in Tasks 1-5

- [ ] **Step 1: Update the project overview decision and notification truth**

Revise the F010/F011 rows and Admin Portal section to state this exact matrix in prose:

```text
Assign creator, Retain reported content, and Approve AI-flagged content do not require a manual reason. Remove creator, Remove reported content, Reject AI-flagged content, and both Appeal decisions require 10-500 characters. Every action retains confirmation. Reason-free persisted actions receive stable internal audit text; Retain sends no author notification. Creator assignment uses the creator-award trigger, report removal uses its existing notification, and real uncertain posts moving from Pending to Approved use the publication-success trigger. The isolated AI adapter does not create real notifications.
```

Update the completed/pending checklist so it distinguishes the newly implemented database notification foundation from still-pending Gemini moderation and FCM push delivery. Record the corrected edge-to-edge recent card media and stage-bounded `object-contain` Post Detail viewer.

- [ ] **Step 2: Update setup guidance**

In `docs/setup.md`, document that applying the latest `chat.sql` installs three system notification transitions: creator award, post rejection, and Pending-to-Approved publication. Preserve the direct-PowerShell instruction and the truthful statement that the AI queue remains local until Gemini integration.

- [ ] **Step 3: Run the complete Admin Portal verification**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\admin'
npm test
npm run typecheck
npm run build
```

Expected: every Vitest test passes, TypeScript reports no errors, and Vite produces a successful production build.

- [ ] **Step 4: Run the complete API verification**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\services\api'
npm test
npm run typecheck
npm run build
```

Expected: every Node test passes and both TypeScript commands finish successfully.

- [ ] **Step 5: Run the unchanged mobile regression baseline**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\mobile'
flutter test --reporter compact
flutter analyze
```

Expected: all Flutter tests pass and analysis reports no issues.

- [ ] **Step 6: Inspect repository quality gates**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git diff --check
git status --short
git diff --stat
```

Expected: `git diff --check` prints nothing; status contains only the intended documentation changes after Tasks 1-5 have been committed.

- [ ] **Step 7: Verify the live portal interactions in the in-app browser**

Start the API and Admin Portal in hidden PowerShell sessions if their existing local processes are no longer running. Use the in-app browser workflow and verify:

```text
Users: Assign creator opens confirmation with blank reason; Remove creator shows inline reason validation.
Reports: Retain opens confirmation with blank reason; Remove shows inline reason validation.
AI-Flagged Content: Approve opens confirmation with blank reason; Reject shows inline validation; tabs have no counts.
Appeals: Approve and Reject both show inline validation when the reason is invalid.
Media: recent images touch the media bounds; hover lift and border remain fully visible; portrait and landscape Post Detail images remain completely inside the media stage; arrows and dots still work.
```

Cancel each confirmation used against a persistent Users, Reports, or Appeals record. AI decisions may be confirmed because they mutate only the isolated in-memory adapter.

- [ ] **Step 8: Record verification evidence in `Project_Overview.md`**

Add the exact Admin/API/Flutter passing totals, the date 1 August 2026, and a concise browser acceptance record. Do not claim remote Supabase SQL was applied or Gemini was connected.

- [ ] **Step 9: Commit documentation and verification evidence**

```powershell
Set-Location 'C:\Chan Ming Jiang\Degree\Sem 5\CyanZone'
git add -- Project_Overview.md docs/setup.md
git commit -m "docs: record admin interaction verification"
git status --short
```

Expected: the commit succeeds and the working tree is clean.

## Completion criteria

- [ ] All positive actions named in the approved matrix reach confirmation without a manual reason.
- [ ] Every punitive action and both Appeal actions display actionable inline validation for an invalid reason.
- [ ] API validation accepts only the approved blank-reason paths and supplies stable non-null audit reasons before RPC calls.
- [ ] Creator assignment, report removal, Appeal decisions, rejected posts, and real Pending-to-Approved posts have the specified notification foundations; Report Retain has none.
- [ ] AI queue tabs have no numeric badges and the temporary queue remains isolated.
- [ ] Recent post images fill their media region and hover without clipping.
- [ ] Post Detail fully contains portrait, landscape, and square images while retaining arrows and dots.
- [ ] Admin, API, and Flutter verification passes directly in PowerShell.
- [ ] Browser acceptance confirms the visible interaction flow without unintended persistent mutations.
- [ ] Documentation remains truthful about remote SQL state, Gemini, FCM, and PowerShell execution.
