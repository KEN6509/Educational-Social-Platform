# Administration Portal Before AI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete pre-AI CyanZone Administration Portal for users, creator requests, reports, appeals, and a temporary mock-backed AI-Flagged Content UI.

**Architecture:** React uses a route-aware casework shell and typed feature clients. Real administrator reads and decisions go through an authenticated Express Admin API backed by a focused repository and transactional Supabase RPCs; the AI-Flagged Content page uses one isolated local mock adapter. Every real decision is validated, confirmed, audited, and notified atomically.

**Tech Stack:** React 18, TypeScript, Vite, Tailwind CSS, React Router, Vitest, Testing Library, Node.js, Express, Zod, Supabase JS, PostgreSQL/RLS, Node Test Runner, Supertest.

---

## Execution rules

- Run every terminal command directly in the user's PowerShell environment
  outside the Codex sandbox.
- Use the approved visual source:
  `docs/superpowers/specs/assets/2026-07-31-admin-portal-casework-desk.png`.
- Follow TDD: write the focused failing test, observe the intended failure, add
  the minimum implementation, and rerun the focused test.
- Preserve existing mobile, chat, notification, and unrelated work.
- Do not connect Gemini in this milestone.
- Do not expose permanent account deletion.
- Use frequent focused commits, then create the final milestone commit with the
  exact message `Admin Portal - before AI-integration`.

## File structure

### Database

- Create `supabase/admin_portal.sql`
  - schema additions, indexes, administrator audit table, duplicate-report
    protection, administrator appeal access, and transactional decision RPCs.
- Modify `supabase/README.md`
  - application order and verification queries.

### Express API

- Create `services/api/src/app.ts`
  - testable Express application factory.
- Modify `services/api/src/server.ts`
  - start the exported application.
- Modify `services/api/src/config/env.ts`
  - validated report threshold.
- Create `services/api/src/admin/adminTypes.ts`
  - view models, decision types, pagination, and repository contracts.
- Create `services/api/src/admin/adminSchemas.ts`
  - Zod request/query schemas.
- Create `services/api/src/admin/adminAuth.ts`
  - bearer-token and active-administrator authorization.
- Create `services/api/src/admin/adminRepository.ts`
  - Supabase reads and RPC calls.
- Create `services/api/src/admin/adminService.ts`
  - orchestration, grouping, conflict handling, and safe view-model mapping.
- Create `services/api/src/admin/adminRouter.ts`
  - protected portal endpoints.
- Modify `services/api/src/routes/admin.ts`
  - retain bootstrap and mount protected routes.
- Create focused `*.test.ts` files beside the API modules.
- Create `services/api/src/all.test.ts`
  - one Windows-safe Node Test Runner entry point that imports each focused
    test file as it is added.
- Modify `services/api/package.json` and `services/api/package-lock.json`
  - test command and Supertest dependencies.

### React Administration Portal

- Modify `apps/admin/package.json` and `apps/admin/package-lock.json`
  - React Router and component-test dependencies.
- Modify `apps/admin/vite.config.ts`
  - Vitest/jsdom configuration.
- Create `apps/admin/src/test/setup.ts`
  - jest-dom setup.
- Create `apps/admin/src/types/admin.ts`
  - shared portal view models.
- Create `apps/admin/src/lib/adminApi.ts`
  - authenticated typed API client.
- Create `apps/admin/src/auth/AdminAuthBoundary.tsx`
  - existing session/role behavior as a focused boundary.
- Create `apps/admin/src/layout/AdminPortalLayout.tsx`
  - navigation, narrow-width behavior, identity, logout, and route outlet.
- Create `apps/admin/src/components/casework/*`
  - shared queue, tabs, status, detail, decision, confirmation, and state views.
- Create feature folders under `apps/admin/src/features/` for:
  - `overview`;
  - `users`;
  - `creatorRequests`;
  - `reports`;
  - `appeals`;
  - `aiFlagged`.
- Modify `apps/admin/src/App.tsx`
  - route composition.
- Modify `apps/admin/src/styles.css`
  - approved visual tokens and shared layout primitives.
- Create focused `*.test.tsx` files beside components/pages.

## Task 1: Install and configure test/runtime dependencies

**Files:**
- Modify: `apps/admin/package.json`
- Modify: `apps/admin/package-lock.json`
- Modify: `apps/admin/vite.config.ts`
- Create: `apps/admin/src/test/setup.ts`
- Create: `apps/admin/src/test/smoke.test.tsx`
- Create: `services/api/src/all.test.ts`
- Modify: `services/api/package.json`
- Modify: `services/api/package-lock.json`

- [ ] **Step 1: Install Admin dependencies directly in PowerShell**

Run:

```powershell
cd apps/admin
npm install react-router-dom
npm install --save-dev vitest jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom
```

Expected: `package.json` and `package-lock.json` contain the new dependencies.

- [ ] **Step 2: Install API test dependencies directly in PowerShell**

Run:

```powershell
cd services/api
npm install --save-dev supertest @types/supertest
```

Expected: `package.json` and `package-lock.json` contain Supertest.

- [ ] **Step 3: Write the failing Admin smoke test**

Create `apps/admin/src/test/smoke.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { PortalTestMarker } from './PortalTestMarker';

describe('Administration Portal test setup', () => {
  it('renders React components in jsdom', () => {
    render(<PortalTestMarker />);
    expect(screen.getByText('Portal tests ready')).toBeInTheDocument();
  });
});
```

Run:

```powershell
cd apps/admin
npm test
```

Expected: FAIL because `PortalTestMarker` and the test script do not exist.

- [ ] **Step 4: Configure Vitest and make the smoke test pass**

Change the config import so the `test` property is typed, then add Vitest:

```ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    css: true,
  },
});
```

Create `apps/admin/src/test/setup.ts`:

```ts
import '@testing-library/jest-dom/vitest';
```

Create `apps/admin/src/test/PortalTestMarker.tsx`:

```tsx
export function PortalTestMarker() {
  return <span>Portal tests ready</span>;
}
```

Add scripts:

```json
"test": "vitest run",
"test:watch": "vitest"
```

Create `services/api/src/all.test.ts`:

```ts
import './lib/passwordPolicy.test.js';
```

Use that Windows-safe aggregate entry point for the API test script:

```json
"test": "tsx --test src/all.test.ts"
```

Run:

```powershell
cd apps/admin
npm test

cd ../../services/api
npm test
```

Expected: the Admin smoke test and existing API password-policy tests pass.

- [ ] **Step 5: Commit**

```powershell
git add -- apps/admin/package.json apps/admin/package-lock.json apps/admin/vite.config.ts apps/admin/src/test services/api/package.json services/api/package-lock.json services/api/src/all.test.ts
git commit -m "test: add administration portal test foundations"
```

## Task 2: Add the Administration Portal database contract

**Files:**
- Create: `supabase/admin_portal.sql`
- Create: `services/api/src/admin/adminSql.test.ts`
- Modify: `supabase/README.md`

- [ ] **Step 1: Write the failing SQL contract test**

Create `services/api/src/admin/adminSql.test.ts`:

```ts
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const sql = readFileSync(
  new URL('../../../../supabase/admin_portal.sql', import.meta.url),
  'utf8',
).toLowerCase();

test('admin portal SQL defines audit and decision boundaries', () => {
  assert.match(sql, /create table if not exists public\.admin_action_audit/);
  assert.match(sql, /previous_state jsonb/);
  assert.match(sql, /new_state jsonb/);
  assert.match(sql, /review_creator_request/);
  assert.match(sql, /decide_report_case/);
  assert.match(sql, /decide_post_appeal/);
  assert.match(sql, /three unique reporters/);
});

test('admin portal SQL prevents duplicate unresolved reports', () => {
  assert.match(
    sql,
    /reports_one_unresolved_per_reporter_target/,
  );
});
```

Add the new test to `services/api/src/all.test.ts`:

```ts
import './admin/adminSql.test.js';
```

Run:

```powershell
cd services/api
npm test
```

Expected: FAIL because `supabase/admin_portal.sql` does not exist.

- [ ] **Step 2: Create the idempotent schema additions**

Create `supabase/admin_portal.sql` with:

```sql
create table if not exists public.admin_action_audit (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete restrict,
  action_type text not null,
  target_type text not null,
  target_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 10 and 500),
  previous_state jsonb not null default '{}'::jsonb,
  new_state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_action_audit_created_idx
on public.admin_action_audit (created_at desc);

create unique index if not exists reports_one_unresolved_per_reporter_target
on public.reports (reporter_id, target_type, target_id)
where status in ('open', 'reviewing');

alter table public.admin_action_audit enable row level security;

drop policy if exists "Admins view audit records"
on public.admin_action_audit;
create policy "Admins view audit records"
on public.admin_action_audit for select
to authenticated
using (public.is_current_user_admin());

drop policy if exists "Admins view post appeals"
on public.post_appeals;
create policy "Admins view post appeals"
on public.post_appeals for select
to authenticated
using (public.is_current_user_admin());
```

Add security-definer RPCs with explicit `search_path = public`, administrator
checks, row locking, state validation, 10-500 reason validation, audit inserts,
business-state updates, and notification inserts:

```sql
public.set_user_account_status(
  p_user_id uuid,
  p_status text,
  p_reason text
)

public.set_user_creator_status(
  p_user_id uuid,
  p_is_creator boolean,
  p_reason text
)

public.review_creator_request(
  p_request_id uuid,
  p_decision text,
  p_reason text
)

public.decide_report_case(
  p_target_type text,
  p_target_id uuid,
  p_decision text,
  p_reason text
)

public.decide_post_appeal(
  p_appeal_id uuid,
  p_decision text,
  p_reason text
)
```

The report RPC must document and enforce **three unique reporters** before a
Pending Review case can be decided. `retain` maps all unresolved rows to
`dismissed`; `remove` maps them to `resolved` and sets the target moderation
status to `removed`.

- [ ] **Step 3: Add grants and denial rules**

Revoke public/anon execution and grant only `authenticated`. Reject:

- self-suspension;
- invalid states or actions;
- already-decided requests/appeals/cases;
- report cases below three unique reporters;
- targets other than post/comment for report decisions.

- [ ] **Step 4: Document application and verification**

Append an `Administration Portal` section to `supabase/README.md` stating that
`admin_portal.sql` runs after `chat.sql`, with this verification query:

```sql
select to_regclass('public.admin_action_audit');

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'set_user_account_status',
    'set_user_creator_status',
    'review_creator_request',
    'decide_report_case',
    'decide_post_appeal'
  );
```

- [ ] **Step 5: Run focused tests**

```powershell
cd services/api
npm test
```

Expected: SQL contract and password-policy tests pass.

- [ ] **Step 6: Commit**

```powershell
git add -- supabase/admin_portal.sql supabase/README.md services/api/src/admin/adminSql.test.ts services/api/src/all.test.ts
git commit -m "feat: add administration portal database contract"
```

## Task 3: Create the testable API application and administrator authorization

**Files:**
- Create: `services/api/src/app.ts`
- Modify: `services/api/src/server.ts`
- Modify: `services/api/src/config/env.ts`
- Create: `services/api/src/admin/adminAuth.ts`
- Create: `services/api/src/admin/adminAuth.test.ts`
- Modify: `services/api/src/routes/admin.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing authorization tests**

Use an injected verifier:

```ts
export type AdminIdentity = {
  id: string;
  email: string;
};

export type VerifyAdmin = (token: string) => Promise<AdminIdentity>;
```

Test:

```ts
test('rejects requests without a bearer token', async () => {
  const response = await request(createApp(testDependencies))
    .get('/admin/overview');
  assert.equal(response.status, 401);
});

test('passes the verified administrator to protected routes', async () => {
  const response = await request(createApp(testDependencies))
    .get('/admin/overview')
    .set('Authorization', 'Bearer valid-token');
  assert.equal(response.status, 200);
});
```

Run `npm test`.

Expected: FAIL because `createApp` and `adminAuth` do not exist.

Add `./admin/adminAuth.test.js` to `services/api/src/all.test.ts` before running
the aggregate test command.

- [ ] **Step 2: Implement bearer authorization**

`adminAuth.ts` must:

```ts
const header = req.header('authorization');
if (!header?.startsWith('Bearer ')) {
  return res.status(401).json({ error: 'Administrator session required.' });
}
const token = header.slice('Bearer '.length).trim();
const identity = await verifyAdmin(token);
res.locals.admin = identity;
return next();
```

The production verifier calls `supabaseAdmin.auth.getUser(token)`, then reads
`profiles.is_admin` and `profiles.account_status`. Missing/invalid sessions
return 401; non-admin or non-active profiles return 403.

- [ ] **Step 3: Extract the Express app**

Create:

```ts
export function createApp(dependencies: AppDependencies) {
  const app = express();
  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '2mb' }));
  app.use('/admin', createAdminRouter(dependencies));
  app.use('/health', healthRouter);
  return app;
}
```

`server.ts` imports `createApp(productionDependencies)` and calls `listen`.

Add to `env.ts`:

```ts
REPORT_REVIEW_THRESHOLD: z.coerce.number().int().min(1).default(3),
```

- [ ] **Step 4: Run tests and typecheck**

```powershell
cd services/api
npm test
npm run typecheck
```

Expected: authorization tests pass and TypeScript reports no errors.

- [ ] **Step 5: Commit**

```powershell
git add -- services/api/src/app.ts services/api/src/server.ts services/api/src/config/env.ts services/api/src/admin/adminAuth.ts services/api/src/admin/adminAuth.test.ts services/api/src/routes/admin.ts services/api/src/all.test.ts
git commit -m "feat: authorize administration portal API"
```

## Task 4: Define typed Admin API schemas, repository, and overview

**Files:**
- Create: `services/api/src/admin/adminTypes.ts`
- Create: `services/api/src/admin/adminSchemas.ts`
- Create: `services/api/src/admin/adminRepository.ts`
- Create: `services/api/src/admin/adminService.ts`
- Create: `services/api/src/admin/adminService.test.ts`
- Create: `services/api/src/admin/adminRouter.ts`
- Create: `services/api/src/admin/adminRouter.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing schema and overview tests**

Define the expected overview:

```ts
const expected = {
  pendingCreatorRequests: 2,
  pendingReportCases: 1,
  pendingAppeals: 3,
  recentDecisions: [],
};
```

Assert:

- page sizes below 1 or above 50 fail;
- invalid statuses fail;
- overview counts grouped report targets, not raw reports;
- reports below three unique reporters are excluded.

Add `./admin/adminService.test.js` and `./admin/adminRouter.test.js` to
`services/api/src/all.test.ts` before running `npm test`.

- [ ] **Step 2: Add shared contracts**

Create:

```ts
export type PageRequest = {
  page: number;
  pageSize: number;
};

export type PageResult<T> = {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
};

export type DecisionInput = {
  decision: string;
  reason: string;
};

export type OverviewView = {
  pendingCreatorRequests: number;
  pendingReportCases: number;
  pendingAppeals: number;
  recentDecisions: AuditView[];
};
```

Define feature view models with explicit nullable fields and ISO timestamp
strings. Do not return raw Supabase response shapes from routes.

- [ ] **Step 3: Add Zod schemas**

Use:

```ts
export const pageSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

export const reasonSchema = z.string().trim().min(10).max(500);
```

Add exact enums for account, creator-request, report, appeal, and decision
states.

- [ ] **Step 4: Implement repository and overview service**

The repository owns Supabase query syntax. The service:

- combines count queries;
- groups reports by target;
- applies the server threshold;
- maps audit rows to safe view models;
- throws typed `AdminNotFoundError`, `AdminConflictError`, and
  `AdminValidationError`.

- [ ] **Step 5: Expose and test `/admin/overview`**

Route errors map to:

- validation -> 400;
- authentication -> 401;
- authorization -> 403;
- not found -> 404;
- stale/already decided -> 409;
- unknown -> 500 with `Unable to complete the administrator request.`

Run:

```powershell
cd services/api
npm test
npm run typecheck
```

Expected: all overview, grouping, router, auth, SQL, and password tests pass.

- [ ] **Step 6: Commit**

```powershell
git add -- services/api/src/admin
git commit -m "feat: add typed administration portal API foundation"
```

## Task 5: Implement Users and Creator Requests API

**Files:**
- Modify: `services/api/src/admin/adminTypes.ts`
- Modify: `services/api/src/admin/adminSchemas.ts`
- Modify: `services/api/src/admin/adminRepository.ts`
- Modify: `services/api/src/admin/adminService.ts`
- Modify: `services/api/src/admin/adminService.test.ts`
- Modify: `services/api/src/admin/adminRouter.ts`
- Modify: `services/api/src/admin/adminRouter.test.ts`

- [ ] **Step 1: Write failing user-list/detail tests**

Cover:

- trimmed name/email search;
- account and creator filters;
- stable created-at pagination;
- public profile and recent published content mapping;
- missing user -> 404.

- [ ] **Step 2: Implement user reads**

Expose:

```text
GET /admin/users
GET /admin/users/:userId
```

Return only profile/public-content fields from the approved design.

- [ ] **Step 3: Write failing user-decision tests**

Cover:

- 10-500 reason;
- self-suspension rejection;
- active <-> suspended only;
- assign/remove creator;
- RPC conflict -> HTTP 409.

- [ ] **Step 4: Implement user decisions**

Expose:

```text
POST /admin/users/:userId/account-status
POST /admin/users/:userId/creator-status
```

Request bodies:

```ts
{ status: 'active' | 'suspended', reason: string }
{ isCreator: boolean, reason: string }
```

Call only the trusted RPCs from Task 2.

- [ ] **Step 5: Write and implement Creator Request endpoints**

Cover and expose:

```text
GET /admin/creator-requests
GET /admin/creator-requests/:requestId
POST /admin/creator-requests/:requestId/decision
```

Decision body:

```ts
{ decision: 'approved' | 'rejected', reason: string }
```

The detail includes the profile, request, account standing, and latest published
posts. Completed requests include reviewer, timestamp, and note.

- [ ] **Step 6: Run tests/typecheck and commit**

```powershell
cd services/api
npm test
npm run typecheck

cd ../..
git add -- services/api/src/admin
git commit -m "feat: add user and creator administration API"
```

## Task 6: Implement Reports and Appeals API

**Files:**
- Modify the same API admin files from Task 5.

- [ ] **Step 1: Write failing report grouping tests**

Use fixtures containing:

- seven reports for one post;
- two reports for a second post;
- three reports for one comment;
- duplicate reporters in historical resolved rows.

Assert:

- only the seven-report post and three-report comment appear Pending Review;
- total is two grouped cases, not ten raw rows;
- reason counts and unique reporters are correct;
- stored states map to Pending Review, Reviewing, Resolved, and Dismissed.

- [ ] **Step 2: Implement report reads**

Expose:

```text
GET /admin/report-cases
GET /admin/report-cases/:targetType/:targetId
```

The detail maps post/comment context, owner, grouped reasons, unique reporters,
history, visibility, and previous decision fields.

- [ ] **Step 3: Write failing report decision tests**

Assert:

- `retain` and `remove` require a valid reason;
- below-threshold and already-decided cases return 409;
- repository RPC failures preserve the safe API error contract.

- [ ] **Step 4: Implement report decisions**

Expose:

```text
POST /admin/report-cases/:targetType/:targetId/decision
```

Body:

```ts
{ decision: 'retain' | 'remove', reason: string }
```

- [ ] **Step 5: Write failing appeal tests**

Cover Pending/Approved/Rejected filtering, rejected post evidence, missing post,
valid decisions, and stale decisions.

- [ ] **Step 6: Implement appeal reads and decisions**

Expose:

```text
GET /admin/appeals
GET /admin/appeals/:appealId
POST /admin/appeals/:appealId/decision
```

Body:

```ts
{ decision: 'approved' | 'rejected', reason: string }
```

- [ ] **Step 7: Run and commit**

```powershell
cd services/api
npm test
npm run typecheck

cd ../..
git add -- services/api/src/admin
git commit -m "feat: add report and appeal administration API"
```

## Task 7: Create the typed React client and authentication boundary

**Files:**
- Create: `apps/admin/src/types/admin.ts`
- Create: `apps/admin/src/lib/adminApi.ts`
- Create: `apps/admin/src/lib/adminApi.test.ts`
- Create: `apps/admin/src/auth/AdminAuthBoundary.tsx`
- Create: `apps/admin/src/auth/AdminAuthBoundary.test.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing client tests**

Mock `fetch` and assert:

- bearer access token is attached;
- query parameters are encoded;
- 401, 403, 409, and general failures become typed client errors;
- valid JSON maps to the shared TypeScript types.

- [ ] **Step 2: Define portal types**

Mirror the API view models exactly. Define:

```ts
export type AdminApiErrorCode =
  | 'unauthenticated'
  | 'forbidden'
  | 'validation'
  | 'not-found'
  | 'conflict'
  | 'server';

export class AdminApiError extends Error {
  constructor(
    public readonly code: AdminApiErrorCode,
    message: string,
  ) {
    super(message);
  }
}
```

- [ ] **Step 3: Implement the client**

Use `VITE_API_URL`, retrieve the current Supabase access token, set
`Authorization: Bearer`, and parse the safe API error body.

- [ ] **Step 4: Extract and test the auth boundary**

Move the current session and active-admin check out of `App.tsx`. Verify:

- checking screen;
- signed-out login;
- active admin portal;
- unauthorized account message;
- API 401/403 sign-out path.

- [ ] **Step 5: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/types apps/admin/src/lib/adminApi.ts apps/admin/src/lib/adminApi.test.ts apps/admin/src/auth apps/admin/src/App.tsx
git commit -m "feat: add administration portal client boundary"
```

## Task 8: Build the approved portal shell and shared casework components

**Files:**
- Create: `apps/admin/src/layout/AdminPortalLayout.tsx`
- Create: `apps/admin/src/layout/AdminPortalLayout.test.tsx`
- Create: `apps/admin/src/components/casework/CaseworkList.tsx`
- Create: `apps/admin/src/components/casework/CaseworkTabs.tsx`
- Create: `apps/admin/src/components/casework/StatusBadge.tsx`
- Create: `apps/admin/src/components/casework/DecisionPanel.tsx`
- Create: `apps/admin/src/components/casework/DecisionDialog.tsx`
- Create: `apps/admin/src/components/casework/AsyncState.tsx`
- Create: `apps/admin/src/components/casework/casework.test.tsx`
- Modify: `apps/admin/src/styles.css`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing navigation/layout tests**

Assert all labels exist, active route is visible, counts render, logout opens the
existing dialog, and AI-Flagged Content is enabled.

- [ ] **Step 2: Implement route-aware shell**

Use `react-router-dom` with:

```text
/
/users
/creator-requests
/reports
/appeals
/ai-flagged
```

Use the approved light sidebar, split workspace, DM Sans/Nunito, and CyanZone
tokens. Do not add charts or generic metric cards.

- [ ] **Step 3: Write failing shared-component tests**

Cover:

- accessible tab selection;
- list selection;
- loading/empty/error/retry states;
- 10-500 DecisionPanel reason validation;
- confirmation consequences;
- busy/disabled submission;
- Escape cancellation only when idle.

- [ ] **Step 4: Implement shared components**

Use shared props:

```ts
type DecisionPanelProps = {
  reason: string;
  onReasonChange: (value: string) => void;
  primaryLabel: string;
  dangerLabel?: string;
  isSubmitting: boolean;
  onPrimary: () => void;
  onDanger?: () => void;
};
```

Keep feature-specific text outside shared components.

- [ ] **Step 5: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/layout apps/admin/src/components/casework apps/admin/src/styles.css apps/admin/src/App.tsx
git commit -m "feat: build administration portal casework shell"
```

## Task 9: Implement Overview and Users pages

**Files:**
- Create: `apps/admin/src/features/overview/OverviewPage.tsx`
- Create: `apps/admin/src/features/overview/OverviewPage.test.tsx`
- Create: `apps/admin/src/features/users/UsersPage.tsx`
- Create: `apps/admin/src/features/users/UsersPage.test.tsx`
- Create: `apps/admin/src/features/users/UserDetail.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing Overview tests**

Assert operational shortcuts/counts, recent decisions, empty/error/retry states,
and absence of charts/advanced analytics.

- [ ] **Step 2: Implement Overview**

Load `/admin/overview`, render queue shortcuts, and link each count to its route.

- [ ] **Step 3: Write failing Users tests**

Cover search, filters, pagination, selection, narrow-width Back to list,
suspend/reactivate, creator assignment/removal, reason preservation on failure,
confirmation, success refresh, 409 reload, and self-suspension disabled state.

- [ ] **Step 4: Implement Users**

Keep query state in URL search parameters. Fetch list/detail separately. Use the
shared DecisionPanel and DecisionDialog. Never expose permanent deletion.

- [ ] **Step 5: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/features/overview apps/admin/src/features/users apps/admin/src/App.tsx
git commit -m "feat: manage users in administration portal"
```

## Task 10: Implement Creator Requests page

**Files:**
- Create: `apps/admin/src/features/creatorRequests/CreatorRequestsPage.tsx`
- Create: `apps/admin/src/features/creatorRequests/CreatorRequestsPage.test.tsx`
- Create: `apps/admin/src/features/creatorRequests/CreatorRequestDetail.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing tests**

Cover Pending/Approved/Rejected tabs, search, detail evidence, recent content,
reason validation, approval/rejection confirmation, completed-state display,
failure preservation, and success queue refresh.

- [ ] **Step 2: Implement the selected Casework Desk layout**

Match the approved visual:

- request inbox in the middle pane;
- selected profile/evidence in the main pane;
- decision area at the bottom;
- gold pending treatment;
- cyan approval and red rejection.

- [ ] **Step 3: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/features/creatorRequests apps/admin/src/App.tsx
git commit -m "feat: review creator requests in admin portal"
```

## Task 11: Implement Reports page

**Files:**
- Create: `apps/admin/src/features/reports/ReportsPage.tsx`
- Create: `apps/admin/src/features/reports/ReportsPage.test.tsx`
- Create: `apps/admin/src/features/reports/ReportCaseDetail.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing tests**

Cover:

- Pending Review/Reviewing/Resolved/Dismissed tabs;
- grouped case count;
- unique reporters and grouped reasons;
- post and comment context;
- current visibility and history;
- retain/remove decision consequences;
- required reason and confirmation;
- loading/empty/error/retry/stale/success states.

- [ ] **Step 2: Implement Reports**

Use the selected split-pane layout. Label counts as cases, never raw reports.
Render `7 unique reports` in detail while one grouped case occupies one row.

- [ ] **Step 3: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/features/reports apps/admin/src/App.tsx
git commit -m "feat: review reported content in admin portal"
```

## Task 12: Implement Appeals page

**Files:**
- Create: `apps/admin/src/features/appeals/AppealsPage.tsx`
- Create: `apps/admin/src/features/appeals/AppealsPage.test.tsx`
- Create: `apps/admin/src/features/appeals/AppealDetail.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing tests**

Cover Pending/Approved/Rejected, rejected content, original evidence, appeal
reason, missing content, approve/reject confirmation, publish/retain
consequences, and all async states.

- [ ] **Step 2: Implement Appeals**

Reuse the casework primitives. Keep original rejection evidence visually
separate from the user-written appeal and administrator decision reason.

- [ ] **Step 3: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/features/appeals apps/admin/src/App.tsx
git commit -m "feat: decide content appeals in admin portal"
```

## Task 13: Implement isolated mock AI-Flagged Content UI

**Files:**
- Create: `apps/admin/src/features/aiFlagged/aiFlaggedTypes.ts`
- Create: `apps/admin/src/features/aiFlagged/aiFlaggedMockData.ts`
- Create: `apps/admin/src/features/aiFlagged/aiFlaggedMockAdapter.ts`
- Create: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`
- Create: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Write failing isolation tests**

Assert:

- banner text is exactly
  `Preview data - Gemini integration is not connected.`;
- every score is between 0.4 and 0.6 inclusive;
- post and comment cases render;
- decisions require a reason and confirmation;
- local decisions change preview status;
- re-rendering a new page instance restores mock data;
- `fetch` and Supabase methods are never called.

- [ ] **Step 2: Add realistic mock contracts and data**

Define:

```ts
export type AiFlaggedStatus = 'pending' | 'approved' | 'rejected';

export type AiFlaggedCase = {
  id: string;
  targetType: 'post' | 'comment';
  authorName: string;
  authorEmail: string;
  submittedAt: string;
  title: string | null;
  content: string;
  imageUrls: string[];
  riskScore: number;
  evidence: string[];
  status: AiFlaggedStatus;
};
```

Provide at least six cases across pending/approved/rejected and post/comment
types. Use repository-safe public/demo image URLs or no image where appropriate;
never use personal data.

- [ ] **Step 3: Implement local adapter and page**

The adapter clones imported mock rows into component-owned state and exposes
list/detail/decide functions. It imports no API or Supabase module.

- [ ] **Step 4: Run and commit**

```powershell
cd apps/admin
npm test
npm run typecheck

cd ../..
git add -- apps/admin/src/features/aiFlagged apps/admin/src/App.tsx
git commit -m "feat: preview AI-flagged content workflow"
```

## Task 14: Cross-feature error, accessibility, and responsive verification

**Files:**
- Modify focused Admin components/tests discovered by verification.
- Modify API tests discovered by verification.

- [ ] **Step 1: Run full Admin tests**

```powershell
cd apps/admin
npm test
```

Expected: all component and client tests pass with no unhandled act warnings.

- [ ] **Step 2: Run Admin typecheck and production build**

```powershell
npm run typecheck
npm run build
```

Expected: both commands exit 0.

- [ ] **Step 3: Run API tests/typecheck/build**

```powershell
cd ../../services/api
npm test
npm run typecheck
npm run build
```

Expected: all API tests pass and both TypeScript commands exit 0.

- [ ] **Step 4: Run mobile regression verification**

```powershell
cd ../../apps/mobile
flutter test --reporter compact
flutter analyze
```

Expected: all Flutter tests pass and analyzer reports no issues.

- [ ] **Step 5: Run browser workflows directly from PowerShell-hosted apps**

Start API and Admin in hidden PowerShell processes. Verify at desktop and narrow
widths:

- every route and active navigation item;
- list/detail selection;
- Back to list;
- loading, empty, error, and retry;
- each confirmation dialog;
- preserved reason after simulated failure;
- AI preview banner and local reset;
- no horizontal clipping;
- keyboard focus visibility;
- no console errors.

Capture screenshots for the approved reference comparison. Compare the selected
mockup and implementation at the same viewport, correct visible spacing,
typography, border, radius, and hierarchy mismatches, then compare again.

- [ ] **Step 6: Commit verification fixes**

```powershell
git add -- apps/admin services/api
git commit -m "fix: polish administration portal workflows"
```

## Task 15: Update project documentation and create the milestone commit

**Files:**
- Modify: `Project_Overview.md`
- Modify: `docs/setup.md`

- [ ] **Step 1: Update Project Overview**

Record:

- functional Overview, Users, Creator Requests, Reports, and Appeals;
- AI-Flagged Content UI uses temporary mock data only;
- report badge counts grouped cases at three unique reporters;
- database/API/admin verification results;
- Gemini integration remains pending;
- exact mock files that must be deleted/replaced during AI integration.

- [ ] **Step 2: Update setup instructions**

Document:

- `VITE_API_URL`;
- `REPORT_REVIEW_THRESHOLD=3`;
- `admin_portal.sql` execution order;
- direct PowerShell commands for Admin/API development and tests.

- [ ] **Step 3: Run final clean verification**

```powershell
git diff --check
git status --short
```

Expected: only the intended documentation changes remain before the milestone
commit and there are no whitespace errors.

- [ ] **Step 4: Create the exact milestone commit**

```powershell
git add -- Project_Overview.md docs/setup.md
git commit -m "Admin Portal - before AI-integration"
```

- [ ] **Step 5: Confirm final state**

```powershell
git status --short
git log --oneline -15
```

Expected: clean worktree and an `Admin Portal - before AI-integration` commit
above the focused implementation commits.
