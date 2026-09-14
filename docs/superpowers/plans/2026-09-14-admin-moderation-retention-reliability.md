# Admin Moderation Retention and Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make completed AI-Flagged queues administrator-only, make moderation images fully reviewable, enforce Storage-safe seven-day rejected-post cleanup, and make intermittent Admin reads observable and resilient.

**Architecture:** Keep the existing React → Express → Supabase structure. Add database-side prepare/finalize RPCs around a Vercel Cron cleanup service so revision checks are authoritative and Storage deletion still uses the supported API. Improve the existing Admin API client and page state locally instead of adding a new state-management framework, and add sanitized request telemetry at the Express boundary.

**Tech Stack:** React 18, TypeScript, Vitest/Testing Library, Express, Node test runner, Supabase Postgres/Storage JS, Vercel Functions and Vercel Cron.

---

## File Structure

### Files to create

- `apps/admin/src/features/aiFlagged/ModerationImageGallery.tsx` — contained thumbnails, unavailable state, and accessible enlarged preview.
- `apps/admin/src/features/aiFlagged/ModerationImageGallery.test.tsx` — image rendering, failure, and preview interaction coverage.
- `services/api/src/maintenance/rejectedPostCleanup.ts` — bounded cleanup orchestration and result counts.
- `services/api/src/maintenance/rejectedPostCleanup.test.ts` — service behavior for ready, skipped, failed, and retryable items.
- `services/api/src/maintenance/rejectedPostCleanupRepository.ts` — Supabase case selection, RPC, Storage API, and finalization adapter.
- `services/api/src/maintenance/rejectedPostCleanupRepository.test.ts` — adapter query and call contracts.
- `services/api/src/maintenance/maintenanceRouter.ts` — Cron-secret authorization and HTTP response.
- `services/api/src/maintenance/maintenanceRouter.test.ts` — missing/wrong/correct secret coverage.
- `services/api/src/middleware/requestTelemetry.ts` — request IDs, duration measurement, and sanitized structured logs.
- `services/api/src/middleware/requestTelemetry.test.ts` — response header and non-leaking log coverage.
- `supabase/rejected_post_retention_upgrade.sql` — idempotent prepare/finalize cleanup RPCs and retirement of the legacy SQL-only cron.

### Files to modify

- `services/api/src/admin/adminRepository.ts` — administrator-only completed queue filter.
- `services/api/src/admin/adminRepository.test.ts` — completed queue database-filter regression tests.
- `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx` — gallery integration and per-tab resilient state.
- `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx` — stale-data and latest-request tests.
- `apps/admin/src/lib/adminApi.ts` — bounded GET timeout and one safe retry.
- `apps/admin/src/lib/adminApi.test.ts` — retry/non-retry/cache tests.
- `services/api/src/admin/adminRouter.ts` — safe error category for telemetry.
- `services/api/src/createApp.ts` — request telemetry and maintenance router mount.
- `services/api/src/app.test.ts` — app-level telemetry/maintenance composition checks.
- `services/api/src/config/env.ts` — optional validated `CRON_SECRET`.
- `services/api/src/config/env.test.ts` — Cron secret validation.
- `services/api/src/index.ts` — production cleanup composition.
- `services/api/src/all.test.ts` — import new Node test files.
- `services/api/.env.example` — deployment variable documentation.
- `services/api/vercel.json` — daily Cron and verified single function region.
- `services/api/src/admin/adminSql.test.ts` — retention SQL security and behavior contracts.
- `supabase/post_editing.sql` — remove the obsolete SQL-only cleanup scheduler from fresh setup.
- `supabase/README.md` and `docs/setup.md` — migration, Cron secret, region, and verification instructions.

## Task 1: Restrict Completed Queues to Administrator Decisions

**Files:**
- Modify: `services/api/src/admin/adminRepository.test.ts`
- Modify: `services/api/src/admin/adminRepository.ts`

- [ ] **Step 1: Write failing repository tests**

Add a completed-state assertion beside the existing target-type pagination test:

```ts
test('completed moderation queues filter administrator decisions before pagination', async () => {
  const equalityFilters: Array<[string, unknown]> = [];
  const query = {
    select() { return this; },
    eq(column: string, value: unknown) {
      equalityFilters.push([column, value]);
      return this;
    },
    order() { return this; },
    range() { return this; },
    then(resolve: (value: { data: never[]; error: null; count: number }) => unknown) {
      return Promise.resolve({ data: [], error: null, count: 0 }).then(resolve);
    },
  };
  const client = {
    from(table: string) {
      assert.equal(table, 'content_moderation_cases');
      return query;
    },
  } as unknown as SupabaseClient;

  await createAdminRepository(client).listModerationCases({
    page: 1,
    pageSize: 20,
    search: '',
    status: 'approved',
  });

  assert.deepEqual(equalityFilters, [
    ['state', 'approved'],
    ['decision_source', 'admin'],
  ]);
});

test('pending moderation queue does not require a completed decision source', async () => {
  // Use the same recording builder and call with status: 'pending'.
  // The exact expected filter is intentionally limited to the queue state.
  assert.deepEqual(equalityFilters, [['state', 'admin_review']]);
});
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
cd services/api
npx tsx --test src/admin/adminRepository.test.ts
```

Expected: the completed queue test fails because only `state` is filtered.

- [ ] **Step 3: Apply the database filter before pagination**

In `listModerationCases`, add the completed-source condition before target type and `range`:

```ts
let request = client
  .from('content_moderation_cases')
  .select('*', { count: 'exact' })
  .eq('state', databaseState)
  .order('created_at', { ascending: false });

if (query.status !== 'pending') {
  request = request.eq('decision_source', 'admin');
}
if (query.targetType) {
  request = request.eq('target_type', query.targetType);
}
```

- [ ] **Step 4: Run the focused and full API tests**

Run:

```powershell
cd services/api
npx tsx --test src/admin/adminRepository.test.ts
npm test
```

Expected: both commands pass and existing pending pagination remains unchanged.

- [ ] **Step 5: Commit**

```powershell
git add -- services/api/src/admin/adminRepository.ts services/api/src/admin/adminRepository.test.ts
git commit -m "fix: scope completed moderation queues to admin decisions"
```

## Task 2: Add Complete and Recoverable Moderation Image Review

**Files:**
- Create: `apps/admin/src/features/aiFlagged/ModerationImageGallery.tsx`
- Create: `apps/admin/src/features/aiFlagged/ModerationImageGallery.test.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx`

- [ ] **Step 1: Write failing gallery interaction tests**

Create a component test with these concrete assertions:

```tsx
it('contains the full image and opens an enlarged dialog', async () => {
  const user = userEvent.setup();
  render(<ModerationImageGallery imageUrls={['https://cdn.test/portrait.jpg']} />);

  const thumbnail = screen.getByRole('button', { name: 'Enlarge moderated image 1' });
  expect(within(thumbnail).getByRole('img')).toHaveClass('object-contain');

  await user.click(thumbnail);
  expect(screen.getByRole('dialog', { name: 'Moderated image preview' })).toBeVisible();
  await user.keyboard('{Escape}');
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
});

it('replaces a failed image without failing the case', () => {
  render(<ModerationImageGallery imageUrls={['https://cdn.test/missing.jpg']} />);
  fireEvent.error(screen.getByRole('img', { name: 'Moderated post attachment 1' }));
  expect(screen.getByText('Image no longer available')).toBeVisible();
});
```

- [ ] **Step 2: Run the gallery test and confirm it fails**

Run:

```powershell
cd apps/admin
npx vitest run src/features/aiFlagged/ModerationImageGallery.test.tsx
```

Expected: FAIL because the component does not exist.

- [ ] **Step 3: Implement the focused gallery**

Implement one stateful component. Its essential structure is:

```tsx
export function ModerationImageGallery({ imageUrls }: { imageUrls: string[] }) {
  const [failed, setFailed] = useState<Set<string>>(() => new Set());
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!previewUrl) return;
    const close = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setPreviewUrl(null);
    };
    window.addEventListener('keydown', close);
    return () => window.removeEventListener('keydown', close);
  }, [previewUrl]);

  return (
    <>
      <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
        {imageUrls.map((url, index) => failed.has(url) ? (
          <div className="grid min-h-52 place-items-center rounded-lg bg-slate-100 text-sm font-bold text-slate-500" key={url}>
            Image no longer available
          </div>
        ) : (
          <button
            aria-label={`Enlarge moderated image ${index + 1}`}
            className="grid min-h-52 overflow-hidden rounded-lg bg-slate-100 p-2 focus:outline-none focus:ring-4 focus:ring-cyan-100"
            key={url}
            onClick={() => setPreviewUrl(url)}
            type="button"
          >
            <img
              alt={`Moderated post attachment ${index + 1}`}
              className="h-72 w-full object-contain"
              onError={() => setFailed((current) => new Set(current).add(url))}
              src={url}
            />
          </button>
        ))}
      </div>
      {previewUrl ? (
        <div aria-label="Moderated image preview" aria-modal="true" className="fixed inset-0 z-50 grid place-items-center bg-slate-950/80 p-6" role="dialog">
          <button aria-label="Close image preview" className="absolute right-6 top-6 rounded-lg bg-white px-4 py-2 font-bold" onClick={() => setPreviewUrl(null)} type="button">Close</button>
          <img alt="Enlarged moderated post attachment" className="max-h-[85vh] max-w-[90vw] object-contain" src={previewUrl} />
        </div>
      ) : null}
    </>
  );
}
```

Use a backdrop click handler only when `event.target === event.currentTarget`, so clicking the image does not close the preview.

- [ ] **Step 4: Replace the inline cropped images**

In `AiFlaggedContentPage.tsx`, keep the existing section heading and replace the mapped `<img className="aspect-square ... object-cover">` block with:

```tsx
<ModerationImageGallery imageUrls={selected.imageUrls} />
```

Update the page test to query `Moderated post attachment 1`.

- [ ] **Step 5: Run focused Admin tests**

Run:

```powershell
cd apps/admin
npx vitest run src/features/aiFlagged/ModerationImageGallery.test.tsx src/features/aiFlagged/AiFlaggedContentPage.test.tsx
```

Expected: all gallery and AI-Flagged tests pass.

- [ ] **Step 6: Commit**

```powershell
git add -- apps/admin/src/features/aiFlagged/ModerationImageGallery.tsx apps/admin/src/features/aiFlagged/ModerationImageGallery.test.tsx apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx
git commit -m "fix: show complete moderation evidence images"
```

## Task 3: Replace the SQL-Only Cleanup with Revision-Safe RPCs

**Files:**
- Create: `supabase/rejected_post_retention_upgrade.sql`
- Modify: `supabase/post_editing.sql`
- Modify: `services/api/src/admin/adminSql.test.ts`

- [ ] **Step 1: Write failing SQL contract tests**

Read the new migration in `adminSql.test.ts` and assert the agreed boundaries:

```ts
const retentionSql = readFileSync(
  new URL('../../../../supabase/rejected_post_retention_upgrade.sql', import.meta.url),
  'utf8',
).toLowerCase();

test('rejected-post retention uses revision-safe service-role RPCs', () => {
  assert.match(retentionSql, /prepare_expired_rejected_post_cleanup/);
  assert.match(retentionSql, /finalize_expired_rejected_post_cleanup/);
  assert.match(retentionSql, /decision_source\s*=\s*'admin'/);
  assert.match(retentionSql, /completed_at\s*>\s*now\(\)\s*-\s*interval\s*'7 days'/);
  assert.match(retentionSql, /moderation_revision\s+is\s+distinct\s+from/);
  assert.match(retentionSql, /target_snapshot\s*=\s*target_snapshot\s*-\s*'images'/);
  assert.match(retentionSql, /delete\s+from\s+public\.posts/);
  assert.doesNotMatch(retentionSql, /delete\s+from\s+storage\.objects/);
  assert.match(retentionSql, /grant\s+execute[\s\S]*to\s+service_role/);
  assert.match(retentionSql, /cron\.unschedule/);
});
```

- [ ] **Step 2: Run the SQL test and confirm it fails**

Run:

```powershell
cd services/api
npx tsx --test src/admin/adminSql.test.ts
```

Expected: FAIL because the migration does not exist.

- [ ] **Step 3: Create the idempotent retention migration**

The migration must first retire the legacy job without requiring `pg_cron` to exist:

```sql
do $$
begin
  if to_regclass('cron.job') is not null and exists (
    select 1 from cron.job where jobname = 'delete-old-rejected-posts'
  ) then
    perform cron.unschedule('delete-old-rejected-posts');
  end if;
exception when others then
  raise notice 'Legacy rejected-post cron was not installed.';
end
$$;

drop function if exists public.delete_old_rejected_posts();
```

Add a `prepare_expired_rejected_post_cleanup(uuid)` security-definer RPC that:

```sql
select * into v_case
from public.content_moderation_cases
where id = p_case_id
for update;

if not found
  or v_case.target_type <> 'post'
  or v_case.state <> 'rejected'
  or v_case.decision_source <> 'admin'
  or v_case.completed_at > now() - interval '7 days'
then
  return jsonb_build_object('action', 'skip', 'storage_paths', '[]'::jsonb);
end if;

select * into v_post
from public.posts
where id = v_case.target_id
for update;

if not found then
  update public.content_moderation_cases
  set target_snapshot = target_snapshot - 'images', updated_at = now()
  where id = v_case.id;
  return jsonb_build_object('action', 'missing', 'storage_paths', '[]'::jsonb);
end if;

if v_post.moderation_revision is distinct from v_case.moderation_revision
  or v_post.moderation_status not in ('rejected', 'removed')
then
  update public.content_moderation_cases
  set target_snapshot = target_snapshot - 'images', updated_at = now()
  where id = v_case.id;
  return jsonb_build_object('action', 'superseded', 'storage_paths', '[]'::jsonb);
end if;

if v_post.moderation_status = 'rejected' then
  perform set_config('cyanzone.trusted_moderation_update', 'on', true);
  update public.posts
  set moderation_status = 'removed', updated_at = now()
  where id = v_post.id;
end if;

select coalesce(jsonb_agg(image.storage_path order by image.position), '[]'::jsonb)
into v_paths
from public.post_images image
where image.post_id = v_post.id;

return jsonb_build_object('action', 'ready', 'storage_paths', v_paths);
```

Add `finalize_expired_rejected_post_cleanup(uuid)` that locks the same case and post, rechecks the revision and `removed` status, deletes the post, and redacts only the image metadata:

```sql
if v_post.moderation_revision is distinct from v_case.moderation_revision
  or v_post.moderation_status <> 'removed'
then
  return jsonb_build_object('action', 'skip');
end if;

delete from public.posts where id = v_post.id;
update public.content_moderation_cases
set target_snapshot = target_snapshot - 'images', updated_at = now()
where id = v_case.id;
return jsonb_build_object('action', 'deleted');
```

For both functions, `revoke all` from `public`, `anon`, and `authenticated`, then grant execute only to `service_role`.

- [ ] **Step 4: Remove legacy scheduling from fresh setup**

Delete `delete_old_rejected_posts()` and the `cron.schedule` block from `supabase/post_editing.sql`. Do not add SQL writes to `storage.objects`; the API owns physical deletion.

- [ ] **Step 5: Run SQL tests**

Run:

```powershell
cd services/api
npx tsx --test src/admin/adminSql.test.ts src/moderation/moderationSql.test.ts
```

Expected: all SQL contract tests pass.

- [ ] **Step 6: Commit**

```powershell
git add -- supabase/rejected_post_retention_upgrade.sql supabase/post_editing.sql services/api/src/admin/adminSql.test.ts
git commit -m "feat: add revision-safe rejected post retention"
```

## Task 4: Implement Bounded Storage-Safe Cleanup

**Files:**
- Create: `services/api/src/maintenance/rejectedPostCleanup.ts`
- Create: `services/api/src/maintenance/rejectedPostCleanup.test.ts`
- Create: `services/api/src/maintenance/rejectedPostCleanupRepository.ts`
- Create: `services/api/src/maintenance/rejectedPostCleanupRepository.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing service tests**

Define a repository boundary and test one ready case, one superseded case, and one Storage failure:

```ts
test('removes storage before finalizing a ready rejected post', async () => {
  const calls: string[] = [];
  const repository: RejectedPostCleanupRepository = {
    listExpiredCaseIds: async () => ['case-1'],
    prepare: async () => ({ action: 'ready', storagePaths: ['user/post/a.jpg'] }),
    removeStorageObjects: async () => { calls.push('storage'); },
    finalize: async () => { calls.push('database'); return 'deleted'; },
  };

  const result = await createRejectedPostCleanup(repository).run();

  assert.deepEqual(calls, ['storage', 'database']);
  assert.deepEqual(result, { processed: 1, deleted: 1, skipped: 0, failed: 0 });
});

test('does not finalize when Storage deletion fails', async () => {
  let finalized = false;
  const repository: RejectedPostCleanupRepository = {
    listExpiredCaseIds: async () => ['case-1'],
    prepare: async () => ({ action: 'ready', storagePaths: ['user/post/a.jpg'] }),
    removeStorageObjects: async () => { throw new Error('storage failure'); },
    finalize: async () => { finalized = true; return 'deleted'; },
  };

  const result = await createRejectedPostCleanup(repository).run();
  assert.equal(finalized, false);
  assert.equal(result.failed, 1);
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:

```powershell
cd services/api
npx tsx --test src/maintenance/rejectedPostCleanup.test.ts
```

Expected: FAIL because the cleanup service does not exist.

- [ ] **Step 3: Implement the cleanup orchestration**

Use explicit result types:

```ts
export type CleanupPreparation = {
  action: 'ready' | 'missing' | 'superseded' | 'skip';
  storagePaths: string[];
};

export type RejectedPostCleanupRepository = {
  listExpiredCaseIds(batchSize: number): Promise<string[]>;
  prepare(caseId: string): Promise<CleanupPreparation>;
  removeStorageObjects(paths: string[]): Promise<void>;
  finalize(caseId: string): Promise<'deleted' | 'missing' | 'skip'>;
};

export function createRejectedPostCleanup(repository: RejectedPostCleanupRepository) {
  return {
    async run(batchSize = 100) {
      const caseIds = await repository.listExpiredCaseIds(batchSize);
      const result = { processed: 0, deleted: 0, skipped: 0, failed: 0 };
      for (const caseId of caseIds) {
        result.processed += 1;
        try {
          const prepared = await repository.prepare(caseId);
          if (prepared.action !== 'ready') {
            result.skipped += 1;
            continue;
          }
          if (prepared.storagePaths.length > 0) {
            await repository.removeStorageObjects(prepared.storagePaths);
          }
          const finalized = await repository.finalize(caseId);
          finalized === 'deleted' ? result.deleted += 1 : result.skipped += 1;
        } catch {
          result.failed += 1;
        }
      }
      return result;
    },
  };
}
```

- [ ] **Step 4: Write failing adapter contract tests**

Record Supabase builder filters and assert the list query uses:

```ts
assert.deepEqual(filters, [
  ['target_type', 'post'],
  ['state', 'rejected'],
  ['decision_source', 'admin'],
]);
assert.equal(limit, 100);
assert.deepEqual(rpcCalls, [
  ['prepare_expired_rejected_post_cleanup', { p_case_id: 'case-1' }],
  ['finalize_expired_rejected_post_cleanup', { p_case_id: 'case-1' }],
]);
assert.deepEqual(storageRemoveCalls, [['user/post/a.jpg']]);
```

- [ ] **Step 5: Implement the Supabase adapter**

Map RPC snake-case JSON to the service types and keep raw errors internal:

```ts
export function createRejectedPostCleanupRepository(client: SupabaseClient) {
  return {
    async listExpiredCaseIds(batchSize: number) {
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
      const { data, error } = await client
        .from('content_moderation_cases')
        .select('id')
        .eq('target_type', 'post')
        .eq('state', 'rejected')
        .eq('decision_source', 'admin')
        .lte('completed_at', cutoff)
        .order('completed_at', { ascending: true })
        .limit(batchSize);
      if (error) throw new Error('Unable to list rejected-post cleanup cases.');
      return (data ?? []).map((row) => String(row.id));
    },
    async prepare(caseId: string) {
      const { data, error } = await client.rpc('prepare_expired_rejected_post_cleanup', { p_case_id: caseId });
      if (error) throw new Error('Unable to prepare rejected-post cleanup.');
      return mapCleanupPreparation(data);
    },
    async removeStorageObjects(paths: string[]) {
      const { error } = await client.storage.from('images').remove(paths);
      if (error) throw new Error('Unable to remove rejected-post media.');
    },
    async finalize(caseId: string) {
      const { data, error } = await client.rpc('finalize_expired_rejected_post_cleanup', { p_case_id: caseId });
      if (error) throw new Error('Unable to finalize rejected-post cleanup.');
      return mapFinalizeAction(data);
    },
  } satisfies RejectedPostCleanupRepository;
}
```

- [ ] **Step 6: Import the new tests and run them**

Add these imports to `src/all.test.ts`:

```ts
import './maintenance/rejectedPostCleanup.test.js';
import './maintenance/rejectedPostCleanupRepository.test.js';
```

Run:

```powershell
cd services/api
npx tsx --test src/maintenance/rejectedPostCleanup.test.ts src/maintenance/rejectedPostCleanupRepository.test.ts
npm test
```

Expected: all focused and full API tests pass.

- [ ] **Step 7: Commit**

```powershell
git add -- services/api/src/maintenance services/api/src/all.test.ts
git commit -m "feat: clean expired rejected post media safely"
```

## Task 5: Secure and Schedule the Cleanup Endpoint

**Files:**
- Create: `services/api/src/maintenance/maintenanceRouter.ts`
- Create: `services/api/src/maintenance/maintenanceRouter.test.ts`
- Modify: `services/api/src/config/env.ts`
- Modify: `services/api/src/config/env.test.ts`
- Modify: `services/api/src/createApp.ts`
- Modify: `services/api/src/app.test.ts`
- Modify: `services/api/src/index.ts`
- Modify: `services/api/src/all.test.ts`
- Modify: `services/api/.env.example`
- Modify: `services/api/vercel.json`

- [ ] **Step 1: Write failing authorization and response tests**

```ts
test('cleanup endpoint requires the exact Cron bearer secret', async () => {
  const router = createMaintenanceRouter({
    cronSecret: 'c'.repeat(32),
    runRejectedPostCleanup: async () => ({ processed: 1, deleted: 1, skipped: 0, failed: 0 }),
  });
  const app = express().use('/maintenance', router);

  assert.equal((await request(app).get('/maintenance/rejected-posts')).status, 401);
  assert.equal((await request(app).get('/maintenance/rejected-posts').set('Authorization', 'Bearer wrong')).status, 401);
  const accepted = await request(app)
    .get('/maintenance/rejected-posts')
    .set('Authorization', `Bearer ${'c'.repeat(32)}`);
  assert.equal(accepted.status, 200);
  assert.deepEqual(accepted.body, { processed: 1, deleted: 1, skipped: 0, failed: 0 });
});
```

Add an environment test:

```ts
test('Cron cleanup secret is optional locally and requires at least 16 characters', () => {
  assert.equal(parseEnv(requiredEnv).CRON_SECRET, undefined);
  assert.throws(() => parseEnv({ ...requiredEnv, CRON_SECRET: 'short' }));
  assert.equal(parseEnv({ ...requiredEnv, CRON_SECRET: 'c'.repeat(32) }).CRON_SECRET, 'c'.repeat(32));
});
```

- [ ] **Step 2: Run focused tests and confirm they fail**

Run:

```powershell
cd services/api
npx tsx --test src/maintenance/maintenanceRouter.test.ts src/config/env.test.ts
```

Expected: FAIL because the router and environment field are missing.

- [ ] **Step 3: Implement constant-time Cron authorization**

In `maintenanceRouter.ts`, compare equal-length buffers with `timingSafeEqual`:

```ts
function secretMatches(header: string | undefined, expected: string) {
  const supplied = header?.startsWith('Bearer ') ? header.slice(7).trim() : '';
  const left = Buffer.from(supplied);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

router.get('/rejected-posts', async (req, res) => {
  if (!secretMatches(req.header('authorization'), dependencies.cronSecret)) {
    return res.status(401).json({ error: 'Maintenance authorization required.' });
  }
  try {
    return res.json(await dependencies.runRejectedPostCleanup());
  } catch {
    return res.status(500).json({ error: 'Maintenance could not be completed.' });
  }
});
```

- [ ] **Step 4: Add production composition**

Add `CRON_SECRET: z.string().min(16).optional()` to the environment schema. Add `maintenanceRouter?: Router` to `AppDependencies` and mount it only when present:

```ts
if (dependencies.maintenanceRouter) {
  app.use('/maintenance', dependencies.maintenanceRouter);
}
```

In `src/index.ts`, compose the router only when configured:

```ts
const maintenanceRouter = env.CRON_SECRET
  ? createMaintenanceRouter({
      cronSecret: env.CRON_SECRET,
      runRejectedPostCleanup: () => createRejectedPostCleanup(
        createRejectedPostCleanupRepository(supabaseAdmin),
      ).run(100),
    })
  : undefined;
```

Pass it to `createApp` and add the maintenance router test import to `all.test.ts`.

- [ ] **Step 5: Configure the daily production invocation**

Update `services/api/vercel.json` without changing the working rewrite:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "rewrites": [
    { "source": "/(.*)", "destination": "/api" }
  ],
  "crons": [
    { "path": "/maintenance/rejected-posts", "schedule": "17 3 * * *" }
  ]
}
```

Add `CRON_SECRET=` to `.env.example` with a comment that production requires a random value of at least 16 characters.

- [ ] **Step 6: Run focused and full API verification**

Run:

```powershell
cd services/api
npx tsx --test src/maintenance/maintenanceRouter.test.ts src/config/env.test.ts src/app.test.ts
npm test
npm run build
```

Expected: tests and TypeScript build pass.

- [ ] **Step 7: Commit**

```powershell
git add -- services/api/src/maintenance/maintenanceRouter.ts services/api/src/maintenance/maintenanceRouter.test.ts services/api/src/config/env.ts services/api/src/config/env.test.ts services/api/src/createApp.ts services/api/src/app.test.ts services/api/src/index.ts services/api/src/all.test.ts services/api/.env.example services/api/vercel.json
git commit -m "feat: schedule rejected post cleanup"
```

## Task 6: Retry Only Safe Admin Reads

**Files:**
- Modify: `apps/admin/src/lib/adminApi.test.ts`
- Modify: `apps/admin/src/lib/adminApi.ts`

- [ ] **Step 1: Write failing retry tests**

Inject a zero-delay sleep in tests and verify exact call counts:

```ts
it('retries one transient GET failure and caches the successful response', async () => {
  const fetcher = vi
    .fn()
    .mockResolvedValueOnce(new Response(undefined, { status: 503 }))
    .mockResolvedValueOnce(new Response(JSON.stringify({ activeUsers: 4 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }));
  const api = createAdminApi({
    baseUrl: 'https://api.cyanzone.test',
    fetcher,
    getAccessToken: async () => 'access-token',
    sleep: async () => undefined,
  });

  await expect(api.get('/admin/overview')).resolves.toEqual({ activeUsers: 4 });
  await api.get('/admin/overview');
  expect(fetcher).toHaveBeenCalledTimes(2);
});

it.each([400, 401, 403, 404, 409])('does not retry HTTP %s', async (status) => {
  const fetcher = vi.fn(async () => new Response(JSON.stringify({ error: 'safe error' }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  }));
  const api = createAdminApi({ baseUrl, fetcher, getAccessToken, sleep: async () => undefined });
  await expect(api.get('/admin/overview')).rejects.toBeInstanceOf(AdminApiError);
  expect(fetcher).toHaveBeenCalledTimes(1);
});
```

Add separate tests for a thrown `TypeError` network error and an aborted request; each gets at most two attempts and no failed result enters the cache.

- [ ] **Step 2: Run the client tests and confirm they fail**

Run:

```powershell
cd apps/admin
npx vitest run src/lib/adminApi.test.ts
```

Expected: transient GET tests fail with one fetch call.

- [ ] **Step 3: Implement bounded GET attempts**

Extend dependencies with deterministic defaults:

```ts
type AdminApiDependencies = {
  baseUrl: string;
  fetcher: typeof fetch;
  getAccessToken: () => Promise<string | null>;
  requestTimeoutMs?: number;
  retryDelayMs?: number;
  sleep?: (milliseconds: number) => Promise<void>;
};

const RETRYABLE_GET_STATUSES = new Set([500, 502, 503, 504]);
```

Wrap each fetch in an `AbortController`, clearing its timer in `finally`. For GET requests, make at most two attempts. Retry only a thrown network/abort error or a response in `RETRYABLE_GET_STATUSES`; call the injected/default sleep before attempt two. Keep POST at one attempt. Parse and throw non-retryable responses using the existing safe `AdminApiError` mapping. Cache only the resolved value after the final successful attempt.

- [ ] **Step 4: Run client and full Admin tests**

Run:

```powershell
cd apps/admin
npx vitest run src/lib/adminApi.test.ts
npm test
```

Expected: retry tests, cache race tests, and full Admin suite pass.

- [ ] **Step 5: Commit**

```powershell
git add -- apps/admin/src/lib/adminApi.ts apps/admin/src/lib/adminApi.test.ts
git commit -m "fix: retry transient administrator reads"
```

## Task 7: Preserve Per-Tab Data and Ignore Stale Requests

**Files:**
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`

- [ ] **Step 1: Write failing page-state tests**

Use deferred promises to prove the two required behaviors:

```tsx
it('keeps loaded rows visible when their background refresh fails', async () => {
  vi.mocked(adminApi.get)
    .mockResolvedValueOnce({ items: [pendingCase], page: 1, pageSize: 20, total: 1 })
    .mockRejectedValueOnce(new AdminApiError('server', 'Unable to complete the administrator request.'));

  const user = userEvent.setup();
  render(<AiFlaggedContentPage />);
  await screen.findByText('A reviewed post');
  await user.click(screen.getByRole('button', { name: 'Approve content' }));
  await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Confirm approval' }));

  expect(screen.getByText('A reviewed post')).toBeVisible();
  expect(screen.getByRole('alert')).toHaveTextContent('Unable to complete the administrator request.');
});

it('ignores an older tab request that resolves after the current tab', async () => {
  const approved = deferred<AiFlaggedPage>();
  const rejected = deferred<AiFlaggedPage>();
  vi.mocked(adminApi.get).mockImplementation((_path, query) => {
    if (query?.status === 'approved') return approved.promise;
    if (query?.status === 'rejected') return rejected.promise;
    return Promise.resolve({ items: [pendingCase], page: 1, pageSize: 20, total: 1 });
  });

  const user = userEvent.setup();
  render(<AiFlaggedContentPage />);
  await user.click(screen.getByRole('button', { name: 'Approved' }));
  await user.click(screen.getByRole('button', { name: 'Rejected' }));
  rejected.resolve({ items: [rejectedCase], page: 1, pageSize: 20, total: 1 });
  expect(await screen.findByText('Rejected by administrator')).toBeVisible();
  approved.resolve({ items: [approvedCase], page: 1, pageSize: 20, total: 1 });
  expect(screen.queryByText('Approved by administrator')).not.toBeInTheDocument();
});
```

- [ ] **Step 2: Run the focused page tests and confirm they fail**

Run:

```powershell
cd apps/admin
npx vitest run src/features/aiFlagged/AiFlaggedContentPage.test.tsx
```

Expected: rows disappear during reload and the late request can replace the selected tab.

- [ ] **Step 3: Implement per-status queue state**

Use one state entry per tab and a generation ref:

```ts
type QueueLoadState = 'idle' | 'loading' | 'loaded' | 'empty' | 'error';
type QueueState = { rows: AiFlaggedCase[]; state: QueueLoadState; errorMessage: string | null };
const emptyQueue = (): QueueState => ({ rows: [], state: 'idle', errorMessage: null });
const [queues, setQueues] = useState<Record<AiFlaggedStatus, QueueState>>({
  pending: emptyQueue(),
  approved: emptyQueue(),
  rejected: emptyQueue(),
});
const requestGeneration = useRef(0);
```

At load start, increment the generation and change only the target status to `loading` while preserving its rows. After awaiting, return without state changes if the captured generation is no longer current. Set successful non-empty data to `loaded`, empty data to `empty`, and failures to `error` without clearing existing rows.

Render `AsyncState` only when the current status has no rows. With existing rows, render `CaseworkList`, a small `Refreshing…` status while loading, and a compact error banner with **Try again** when refresh fails.

- [ ] **Step 4: Run focused and full Admin tests**

Run:

```powershell
cd apps/admin
npx vitest run src/features/aiFlagged/AiFlaggedContentPage.test.tsx src/features/aiFlagged/ModerationImageGallery.test.tsx
npm test
npm run build
```

Expected: state tests pass and the production build remains code-split without a 500 KB initial-chunk warning.

- [ ] **Step 5: Commit**

```powershell
git add -- apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx
git commit -m "fix: preserve administrator queue state during refresh"
```

## Task 8: Add Sanitized Request Telemetry

**Files:**
- Create: `services/api/src/middleware/requestTelemetry.ts`
- Create: `services/api/src/middleware/requestTelemetry.test.ts`
- Modify: `services/api/src/admin/adminRouter.ts`
- Modify: `services/api/src/createApp.ts`
- Modify: `services/api/src/app.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing telemetry tests**

```ts
test('returns a request ID and logs safe timing fields', async () => {
  const events: RequestTelemetryEvent[] = [];
  const app = express()
    .use(createRequestTelemetry((event) => events.push(event)))
    .get('/test', (_req, res) => res.status(503).json({ error: 'safe' }));

  const response = await request(app).get('/test');
  assert.match(response.headers['x-request-id'], /^[0-9a-f-]{36}$/i);
  assert.equal(events.length, 1);
  assert.deepEqual(
    { method: events[0]?.method, path: events[0]?.path, status: events[0]?.status },
    { method: 'GET', path: '/test', status: 503 },
  );
  assert.equal(typeof events[0]?.durationMs, 'number');
});

test('administrator failures do not log raw database messages', async () => {
  const serialized = JSON.stringify(events);
  assert.doesNotMatch(serialized, /postgres password|select \* from|bearer/i);
  assert.match(serialized, /admin_data|unexpected/);
});
```

- [ ] **Step 2: Run telemetry tests and confirm they fail**

Run:

```powershell
cd services/api
npx tsx --test src/middleware/requestTelemetry.test.ts src/app.test.ts
```

Expected: FAIL because request telemetry does not exist.

- [ ] **Step 3: Implement request IDs and structured completion logs**

```ts
export type RequestTelemetryEvent = {
  requestId: string;
  method: string;
  path: string;
  status: number;
  durationMs: number;
  errorCategory?: string;
};

export function createRequestTelemetry(
  log: (event: RequestTelemetryEvent) => void = (event) => console.info(JSON.stringify(event)),
): RequestHandler {
  return (req, res, next) => {
    const startedAt = performance.now();
    const requestId = randomUUID();
    res.locals.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);
    res.once('finish', () => log({
      requestId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: Math.round((performance.now() - startedAt) * 10) / 10,
      ...(typeof res.locals.errorCategory === 'string'
        ? { errorCategory: res.locals.errorCategory }
        : {}),
    }));
    next();
  };
}
```

Mount this before the routers in `createApp`.

- [ ] **Step 4: Categorize Admin failures without exposing details**

In `sendAdminError`, set a fixed category before the existing safe response:

```ts
res.locals.errorCategory =
  error instanceof AdminValidationError ? 'admin_validation' :
  error instanceof AdminNotFoundError ? 'admin_not_found' :
  error instanceof AdminConflictError ? 'admin_conflict' :
  'admin_unexpected';
```

Set `res.locals.errorCategory = 'unhandled'` in the global error middleware. Do not add the exception message, request body, authorization header, or database query to the event.

- [ ] **Step 5: Import and run telemetry tests**

Add:

```ts
import './middleware/requestTelemetry.test.js';
```

to `all.test.ts`, then run:

```powershell
cd services/api
npx tsx --test src/middleware/requestTelemetry.test.ts src/app.test.ts src/admin/adminRouter.test.ts
npm test
npm run build
```

Expected: every test passes and API clients still receive only safe messages.

- [ ] **Step 6: Commit**

```powershell
git add -- services/api/src/middleware services/api/src/admin/adminRouter.ts services/api/src/createApp.ts services/api/src/app.test.ts services/api/src/all.test.ts
git commit -m "feat: add safe API request telemetry"
```

## Task 9: Document Hosted Migration and Align the API Region

**Files:**
- Modify: `docs/setup.md`
- Modify: `supabase/README.md`
- Modify: `services/api/vercel.json`

- [ ] **Step 1: Verify the actual Supabase region**

In Supabase Dashboard, open the CyanZone project and read the project region under project infrastructure/settings. Do not infer it from the user's location.

If the project reports **Southeast Asia (Singapore)** or `ap-southeast-1`, use Vercel `sin1`:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "regions": ["sin1"],
  "rewrites": [
    { "source": "/(.*)", "destination": "/api" }
  ],
  "crons": [
    { "path": "/maintenance/rejected-posts", "schedule": "17 3 * * *" }
  ]
}
```

If the dashboard reports a different region, pause this single step and select the closest valid Vercel region from Vercel's official Regions documentation; do not commit `sin1` for a non-Singapore database.

- [ ] **Step 2: Document the exact hosted upgrade order**

Add these instructions to both setup documents:

```md
1. Run `supabase/rejected_post_retention_upgrade.sql` once in Supabase SQL Editor.
2. Generate a random `CRON_SECRET` of at least 16 characters.
3. Add the same variable to the API Vercel project's Production environment.
4. Confirm the API function region matches or is nearest to the Supabase project region.
5. Redeploy the API from the merged commit.
6. In Vercel Cron Jobs, confirm `/maintenance/rejected-posts` is enabled.
7. Check the next run's logs for processed, deleted, skipped, and failed counts.
```

State explicitly that the migration unschedules the old `delete-old-rejected-posts` SQL cron and that Storage objects must not be deleted directly from `storage.objects`.

- [ ] **Step 3: Run configuration and documentation checks**

Run:

```powershell
cd services/api
npm test
npm run build
cd ../..
git diff --check
rg -n "rejected_post_retention_upgrade|CRON_SECRET|maintenance/rejected-posts|regions" docs/setup.md supabase/README.md services/api/.env.example services/api/vercel.json
```

Expected: tests/build pass, `git diff --check` is silent, and every deployment requirement is discoverable.

- [ ] **Step 4: Commit**

```powershell
git add -- docs/setup.md supabase/README.md services/api/vercel.json
git commit -m "docs: add rejected post cleanup deployment steps"
```

## Task 10: Final Regression and Deployment Handoff

**Files:**
- Verify all files changed by Tasks 1–9.

- [ ] **Step 1: Run the complete Admin suite and production build**

```powershell
cd apps/admin
npm test
npm run build
```

Expected: all Admin tests pass and the initial production chunk remains below 500 KB.

- [ ] **Step 2: Run the complete API suite and production build**

```powershell
cd services/api
npm test
npm run build
```

Expected: all API tests pass with no TypeScript errors.

- [ ] **Step 3: Run repository hygiene checks**

```powershell
cd ../..
git diff --check
git status --short
```

Expected: `git diff --check` is silent. Only intended source, tests, SQL, and documentation changes are present; generated Admin build metadata is not committed.

- [ ] **Step 4: Perform local behavior checks**

Verify:

1. Pending still loads human-review cases.
2. Approved and Rejected exclude Gemini-only decisions.
3. Portrait and landscape images are fully visible.
4. Preview opens, closes, and handles a missing image.
5. Loaded queue rows remain visible through a failed refresh.
6. A transient GET is attempted no more than twice.
7. API errors return a request ID and never expose raw PostgreSQL/Supabase text.

- [ ] **Step 5: Apply the hosted SQL migration**

Run the complete `supabase/rejected_post_retention_upgrade.sql` in Supabase SQL Editor and verify both RPC names exist. Confirm the legacy `delete-old-rejected-posts` job is absent before enabling the Vercel Cron deployment.

- [ ] **Step 6: Configure and smoke-test production**

Add `CRON_SECRET` to the API Vercel Production environment, merge/deploy the branch, and verify both Vercel projects show **Ready**. Confirm the Admin queue behavior and inspect one API request log for `requestId`, `status`, and `durationMs` only.

Do not manually invoke destructive cleanup against real user data for smoke testing. Validate the job during UAT with a dedicated test post whose rejection time is controlled in a non-production fixture or approved test account.

- [ ] **Step 7: Record the remaining UAT work**

Keep Android FCM foreground/background/terminated delivery and mobile performance timing in the UAT checklist. Do not add more mobile refactoring unless those measurements identify a reproducible bottleneck.
