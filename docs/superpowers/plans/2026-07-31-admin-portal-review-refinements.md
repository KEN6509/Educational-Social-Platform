# Admin Portal Review Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real report metrics, a 15-item scrollable audit history, and complete creator-post review with a five-post carousel, near-full-page post details, comments, and a four-column See All modal.

**Architecture:** Keep the Express Admin API as the only portal data boundary. Extend its typed service/repository layers with real post images and approved comment threads, then compose focused React components inside the existing Users detail page without redesigning the surrounding layout. Keep the report threshold environment-driven so testing uses `1` and deployment can use `1000`.

**Tech Stack:** TypeScript, Express, Supabase/PostgREST, React 18, React Router, Tailwind CSS, Vitest, Testing Library, Node test runner.

---

## File Structure

- Modify `services/api/src/config/env.ts`: expose testable environment parsing and default the local report threshold to one.
- Create `services/api/src/config/env.test.ts`: verify threshold parsing.
- Modify `services/api/.env.example` and `docs/setup.md`: document testing and deployment threshold values.
- Modify `services/api/src/admin/adminTypes.ts`: add report totals and administrator post/comment view types.
- Modify `services/api/src/admin/adminService.ts`: expose user posts/post details and attach total report counts.
- Modify `services/api/src/admin/adminRepository.ts`: query post totals, cover images, complete images, and approved comment threads.
- Create `services/api/src/admin/adminPostViews.ts`: pure post/comment mapping helpers.
- Create `services/api/src/admin/adminPostViews.test.ts`: verify image ordering, counts, and reply mapping.
- Modify `services/api/src/admin/adminRouter.ts`: add protected user-post and post-detail routes.
- Modify `services/api/src/admin/adminService.test.ts`, `adminRouter.test.ts`, and `all.test.ts`: cover the new API behavior.
- Modify `apps/admin/src/types/admin.ts`: mirror the Admin API response contracts.
- Modify `apps/admin/src/features/reports/ReportCaseDetail.tsx` and `ReportsPage.test.tsx`: render total reports and reason percentages.
- Modify `apps/admin/src/features/overview/OverviewPage.tsx` and `OverviewPage.test.tsx`: render 15 decisions in an internal scroll area.
- Create `apps/admin/src/components/casework/FullScreenDialog.tsx`: reusable accessible near-full-page dialog shell.
- Create `apps/admin/src/components/casework/FullScreenDialog.test.tsx`: verify Escape, focus trapping, and restoration.
- Create `apps/admin/src/features/users/RecentPostsCarousel.tsx`: five-item horizontal carousel with side controls.
- Create `apps/admin/src/features/users/AllPostsModal.tsx`: four-column, unfiltered post collection.
- Create `apps/admin/src/features/users/PostDetailModal.tsx`: media viewer, full post fields, and comments below details.
- Create `apps/admin/src/features/users/PostReview.test.tsx`: focused tests for carousel and both modal states.
- Modify `apps/admin/src/features/users/UserDetail.tsx`, `UsersPage.tsx`, and `UsersPage.test.tsx`: integrate real totals and modal data loading.
- Modify `Project_Overview.md`: record the implemented Admin Portal refinements and testing threshold.

### Task 1: Make the report threshold testable and expose report totals

**Files:**
- Create: `services/api/src/config/env.test.ts`
- Modify: `services/api/src/config/env.ts`
- Modify: `services/api/src/all.test.ts`
- Modify: `services/api/.env.example`
- Modify: `docs/setup.md`
- Modify: `services/api/src/admin/adminTypes.ts`
- Modify: `services/api/src/admin/adminService.ts`
- Modify: `services/api/src/admin/adminRepository.ts`
- Modify: `services/api/src/admin/adminService.test.ts`
- Modify: `services/api/src/admin/adminRouter.test.ts`

- [ ] **Step 1: Write the failing environment and report-total tests**

Create `services/api/src/config/env.test.ts`:

```ts
import assert from 'node:assert/strict';
import test from 'node:test';

import { parseEnv } from './env.js';

const requiredEnv = {
  SUPABASE_URL: 'https://project.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role',
  ADMIN_BOOTSTRAP_SECRET: 'a'.repeat(24),
};

test('report review threshold defaults to one for functional testing', () => {
  assert.equal(parseEnv(requiredEnv).REPORT_REVIEW_THRESHOLD, 1);
});

test('report review threshold accepts the deployment value', () => {
  assert.equal(
    parseEnv({ ...requiredEnv, REPORT_REVIEW_THRESHOLD: '1000' })
      .REPORT_REVIEW_THRESHOLD,
    1000,
  );
});
```

Import the new test in `services/api/src/all.test.ts`:

```ts
import './config/env.test.js';
```

In the existing grouped-report test in `adminService.test.ts`, add:

```ts
assert.equal(result.items[0]?.totalReports, 7);
assert.equal(result.items[1]?.totalReports, 3);
```

Add a one-reporter case test:

```ts
test('threshold one exposes a genuine single-reporter case', async () => {
  const row: ReportCaseRow = {
    id: 'report-1',
    targetType: 'post',
    targetId: 'post-1',
    reporterId: 'reporter-1',
    reason: 'Spam',
    description: null,
    status: 'open',
    reviewedBy: null,
    reviewedAt: null,
    resolutionNote: null,
    createdAt: '2026-07-31T00:00:00.000Z',
    targetTitle: 'Reported post',
    targetExcerpt: 'Repeated promotion',
    ownerName: 'Owner',
  };
  const service = createAdminService(
    createRepository({ getReportCaseRows: async () => [row] }),
    1,
  );

  const result = await service.listReportCases({
    page: 1,
    pageSize: 20,
    search: '',
    status: 'open',
    targetType: undefined,
  });

  assert.equal(result.total, 1);
  assert.equal(result.items[0]?.totalReports, 1);
});
```

- [ ] **Step 2: Run the API tests and confirm RED**

Run from `services/api`:

```powershell
npm test
```

Expected: FAIL because `parseEnv` and `totalReports` do not exist.

- [ ] **Step 3: Implement environment parsing and report totals**

Refactor `env.ts`:

```ts
const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ADMIN_BOOTSTRAP_SECRET: z.string().min(24),
  REPORT_REVIEW_THRESHOLD: z.coerce.number().int().min(1).default(1),
  GEMINI_API_KEY: z.string().min(1).optional(),
});

export function parseEnv(input: NodeJS.ProcessEnv | Record<string, string>) {
  return envSchema.parse(input);
}

export const env = parseEnv(process.env);
```

Add `totalReports` to `ReportCaseSummaryView` in `adminTypes.ts`:

```ts
totalReports: number;
```

Set it in `adminService.ts` while grouping:

```ts
totalReports: group.length,
```

Set it in `adminRepository.ts#getReportCaseDetail`:

```ts
totalReports: reports.length,
```

Update the router fixture with `totalReports: 7`. Change `services/api/.env.example` to:

```dotenv
REPORT_REVIEW_THRESHOLD=1
```

Update `docs/setup.md` to state that local functional testing uses `1` and the production deployment value must be set to `1000` before release.

- [ ] **Step 4: Run the API tests and typecheck for GREEN**

```powershell
npm test
npm run typecheck
```

Expected: all API tests and TypeScript checks pass.

- [ ] **Step 5: Commit the threshold and report model**

```powershell
git add -- services/api/src/config services/api/src/all.test.ts services/api/.env.example docs/setup.md services/api/src/admin/adminTypes.ts services/api/src/admin/adminService.ts services/api/src/admin/adminRepository.ts services/api/src/admin/adminService.test.ts services/api/src/admin/adminRouter.test.ts
git commit -m "feat: expose configurable report review metrics"
```

### Task 2: Render report reason percentages

**Files:**
- Modify: `apps/admin/src/types/admin.ts`
- Modify: `apps/admin/src/features/reports/ReportCaseDetail.tsx`
- Modify: `apps/admin/src/features/reports/ReportsPage.test.tsx`

- [ ] **Step 1: Write the failing report presentation test**

Set `totalReports: 7` on the report fixture and add:

```ts
expect(await screen.findByText('7 total reports')).toBeVisible();
expect(screen.getByText('71%')).toBeVisible();
expect(screen.getByText('29%')).toBeVisible();
expect(
  screen.getByRole('progressbar', { name: 'Harmful advice 71%' }),
).toHaveAttribute('aria-valuenow', '71');
```

- [ ] **Step 2: Run the focused Admin test and confirm RED**

Run from `apps/admin`:

```powershell
npm test -- src/features/reports/ReportsPage.test.tsx
```

Expected: FAIL because total counts and percentages are not rendered.

- [ ] **Step 3: Implement totals and percentage bars**

Mirror `totalReports: number` in `apps/admin/src/types/admin.ts`.

In `ReportCaseDetail.tsx`, calculate:

```ts
function reasonPercentage(count: number, total: number) {
  return total === 0 ? 0 : Math.round((count / total) * 100);
}
```

Change the report heading to:

```tsx
<h3 className="font-black">{reportCase.totalReports} total reports</h3>
<p className="mt-1 text-xs text-slate-500">
  {reportCase.uniqueReporters} unique reporters
</p>
```

Render each reason with its count, percentage, and bar:

```tsx
const percentage = reasonPercentage(item.count, reportCase.totalReports);
return (
  <div className="rounded-lg bg-white px-3 py-2" key={item.reason}>
    <div className="flex items-center justify-between gap-3 text-sm">
      <span className="font-semibold text-slate-700">{item.reason}</span>
      <span className="text-xs font-black text-red-700">
        {item.count} · {percentage}%
      </span>
    </div>
    <div
      aria-label={`${item.reason} ${percentage}%`}
      aria-valuemax={100}
      aria-valuemin={0}
      aria-valuenow={percentage}
      className="mt-2 h-1.5 overflow-hidden rounded-full bg-red-100"
      role="progressbar"
    >
      <div
        className="h-full rounded-full bg-red-500"
        style={{ width: `${percentage}%` }}
      />
    </div>
  </div>
);
```

- [ ] **Step 4: Run focused and full Admin tests**

```powershell
npm test -- src/features/reports/ReportsPage.test.tsx
npm test
```

Expected: focused and full Admin suites pass.

- [ ] **Step 5: Commit report percentages**

```powershell
git add -- apps/admin/src/types/admin.ts apps/admin/src/features/reports
git commit -m "feat: show report reason percentages"
```

### Task 3: Show 15 scrollable Overview decisions

**Files:**
- Modify: `services/api/src/admin/adminRepository.ts`
- Modify: `apps/admin/src/features/overview/OverviewPage.tsx`
- Modify: `apps/admin/src/features/overview/OverviewPage.test.tsx`

- [ ] **Step 1: Write the failing Overview UI test**

Build 15 audit fixtures and return them from the test API:

```ts
const recentDecisions = Array.from({ length: 15 }, (_, index) => ({
  id: `audit-${index + 1}`,
  adminId: 'admin-1',
  adminEmail: 'alex@cyanzone.test',
  actionType: 'creator_request.approved',
  targetType: 'creator_request',
  targetId: `request-${index + 1}`,
  reason: `Decision reason ${index + 1}`,
  createdAt: `2026-07-${String(31 - index).padStart(2, '0')}T08:00:00.000Z`,
}));
```

Assert:

```ts
expect(await screen.findAllByTestId('recent-decision')).toHaveLength(15);
expect(screen.getByTestId('recent-decisions-scroll')).toHaveClass(
  'overflow-y-auto',
);
```

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
npm test -- src/features/overview/OverviewPage.test.tsx
```

Expected: FAIL because the test IDs and scroll container are absent.

- [ ] **Step 3: Increase the API limit and constrain the UI panel**

Change the overview audit query in `adminRepository.ts` from `.limit(8)` to:

```ts
.limit(15)
```

In `OverviewPage.tsx`, wrap the mapped decisions with:

```tsx
<div
  className="mt-4 max-h-[32rem] divide-y divide-slate-200 overflow-y-auto rounded-xl border border-slate-200 bg-white"
  data-testid="recent-decisions-scroll"
>
```

Add `data-testid="recent-decision"` to each audit article.

- [ ] **Step 4: Run Admin and API verification**

```powershell
npm test -- src/features/overview/OverviewPage.test.tsx
npm test
```

Run from `services/api`:

```powershell
npm test
```

Expected: all suites pass.

- [ ] **Step 5: Commit the Overview history change**

```powershell
git add -- services/api/src/admin/adminRepository.ts apps/admin/src/features/overview
git commit -m "feat: expand overview decision history"
```

### Task 4: Add typed administrator post data

**Files:**
- Create: `services/api/src/admin/adminPostViews.ts`
- Create: `services/api/src/admin/adminPostViews.test.ts`
- Modify: `services/api/src/all.test.ts`
- Modify: `services/api/src/admin/adminTypes.ts`
- Modify: `services/api/src/admin/adminRepository.ts`
- Modify: `services/api/src/admin/adminService.ts`
- Modify: `services/api/src/admin/adminService.test.ts`

- [ ] **Step 1: Write failing mapper and service tests**

Define the wished-for view contracts in the test:

```ts
test('maps post images in position order and nests replies', () => {
  const result = buildAdminPostDetail({
    post: {
      id: 'post-1',
      author_id: 'creator-1',
      title: 'Repair guide',
      content: 'Full guide',
      tags: ['Technology'],
      moderation_status: 'approved',
      published_at: '2026-07-31T00:00:00.000Z',
      created_at: '2026-07-30T00:00:00.000Z',
    },
    author: { id: 'creator-1', name: 'Ken', avatar_url: null },
    images: [
      { public_url: 'https://img/second.jpg', position: 2 },
      { public_url: 'https://img/first.jpg', position: 1 },
    ],
    comments: [
      {
        id: 'comment-1', author_id: 'member-1', parent_comment_id: null,
        content: 'Helpful', created_at: '2026-07-31T01:00:00.000Z',
      },
      {
        id: 'reply-1', author_id: 'creator-1', parent_comment_id: 'comment-1',
        content: 'Thank you', created_at: '2026-07-31T02:00:00.000Z',
      },
    ],
    profiles: [
      { id: 'member-1', name: 'Member', avatar_url: null },
      { id: 'creator-1', name: 'Ken', avatar_url: null },
    ],
    likeCounts: new Map([['comment-1', 4]]),
  });

  assert.deepEqual(result.images.map((image) => image.url), [
    'https://img/first.jpg',
    'https://img/second.jpg',
  ]);
  assert.equal(result.comments[0]?.replies[0]?.isCreator, true);
  assert.equal(result.comments[0]?.likeCount, 4);
});
```

In `adminService.test.ts`, add repository overrides and assert:

```ts
assert.equal((await service.listUserPosts('user-1')).length, 2);
assert.equal((await service.getPost('post-1')).id, 'post-1');
await assert.rejects(() => service.getPost('missing'), AdminNotFoundError);
```

- [ ] **Step 2: Run API tests and confirm RED**

```powershell
npm test
```

Expected: FAIL because post mapper, repository methods, and service methods do not exist.

- [ ] **Step 3: Add the API view contracts**

Add these types in `adminTypes.ts`:

```ts
export type PostSummaryView = {
  id: string;
  title: string;
  content: string;
  tags: string[];
  moderationStatus: string;
  publishedAt: string | null;
  createdAt: string;
  coverImageUrl: string | null;
  imageCount: number;
  commentCount: number;
};

export type AdminCommentView = {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatarUrl: string | null;
  isCreator: boolean;
  content: string;
  createdAt: string;
  likeCount: number;
  replies: AdminCommentView[];
};

export type AdminPostDetailView = PostSummaryView & {
  authorId: string;
  authorName: string;
  authorAvatarUrl: string | null;
  images: Array<{ url: string; position: number }>;
  comments: AdminCommentView[];
};
```

Extend `UserDetailView` with `publishedPostCount: number`. Add repository methods `listUserPublishedPosts` and `getPostDetail`, and service methods `listUserPosts` and `getPost`.

- [ ] **Step 4: Implement pure post/comment mapping**

In `adminPostViews.ts`, export `buildAdminPostSummary` and `buildAdminPostDetail`. Sort images by `position`, filter images without a usable URL, group replies by `parent_comment_id`, retain chronological parent order, and mark `isCreator` when `author_id === post.author_id`.

Use the exact returned shape from Step 3; top-level comments have their `replies` array populated and replies have an empty `replies` array.

- [ ] **Step 5: Implement repository queries**

In `getUserDetail`, query:

```ts
client.from('posts').select('id', { count: 'exact', head: true })
  .eq('author_id', userId)
  .eq('moderation_status', 'approved');
```

Return `publishedPostCount: postCountResult.count ?? 0` and hydrate only the five existing recent posts with cover images and approved-comment counts.

Implement `listUserPublishedPosts(userId)` using approved posts ordered by `published_at` descending, then batch-query `post_images` and approved `comments` for those post IDs.

Implement `getPostDetail(postId)` by querying the post, ordered `post_images`, approved comments, related profiles, and `comment_likes`. Pass those records into `buildAdminPostDetail`.

- [ ] **Step 6: Implement service not-found behavior**

```ts
listUserPosts: async (userId) => {
  const user = await repository.getUserDetail(userId);
  if (!user) throw new AdminNotFoundError('User not found.');
  return repository.listUserPublishedPosts(userId);
},
getPost: async (postId) => {
  const post = await repository.getPostDetail(postId);
  if (!post) throw new AdminNotFoundError('Post not found.');
  return post;
},
```

- [ ] **Step 7: Run API tests and typecheck**

```powershell
npm test
npm run typecheck
```

Expected: all tests pass, including image ordering and nested reply mapping.

- [ ] **Step 8: Commit the administrator post data layer**

```powershell
git add -- services/api/src/admin services/api/src/all.test.ts
git commit -m "feat: expose administrator post review data"
```

### Task 5: Add protected post routes

**Files:**
- Modify: `services/api/src/admin/adminRouter.ts`
- Modify: `services/api/src/admin/adminRouter.test.ts`

- [ ] **Step 1: Write failing protected route tests**

Extend the test service with `listUserPosts` and `getPost`. Add:

```ts
test('returns published user posts and complete post details', async () => {
  const dependencies = createDependencies(async () => expectedOverview, {
    listUserPosts: async () => [postSummary],
    getPost: async () => postDetail,
  });

  const posts = await request(createApp(dependencies))
    .get('/admin/users/user-1/posts')
    .set('Authorization', 'Bearer valid-token');
  const detail = await request(createApp(dependencies))
    .get('/admin/posts/post-1')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(posts.status, 200);
  assert.equal(posts.body[0].id, 'post-1');
  assert.equal(detail.status, 200);
  assert.equal(detail.body.comments[0].content, 'Helpful');
});
```

- [ ] **Step 2: Run API tests and confirm RED**

```powershell
npm test
```

Expected: FAIL with 404 responses for both new routes.

- [ ] **Step 3: Add routes before the decision routes**

```ts
router.get('/users/:userId/posts', async (req, res) => {
  try {
    const service = dependencies.createService(getRequestContext(req));
    return res.json(await service.listUserPosts(req.params.userId));
  } catch (error) {
    return sendAdminError(res, error);
  }
});

router.get('/posts/:postId', async (req, res) => {
  try {
    const service = dependencies.createService(getRequestContext(req));
    return res.json(await service.getPost(req.params.postId));
  } catch (error) {
    return sendAdminError(res, error);
  }
});
```

- [ ] **Step 4: Run tests and commit**

```powershell
npm test
npm run typecheck
git add -- services/api/src/admin/adminRouter.ts services/api/src/admin/adminRouter.test.ts
git commit -m "feat: add administrator post review routes"
```

### Task 6: Build the accessible full-screen dialog shell

**Files:**
- Create: `apps/admin/src/components/casework/FullScreenDialog.tsx`
- Create: `apps/admin/src/components/casework/FullScreenDialog.test.tsx`

- [ ] **Step 1: Write the failing dialog behavior test**

```tsx
it('closes with Escape, traps Tab, and restores focus', async () => {
  const user = userEvent.setup();
  const onClose = vi.fn();
  render(
    <>
      <button type="button">Origin</button>
      <FullScreenDialog isOpen label="All published posts" onClose={onClose}>
        <button type="button">First</button>
        <button type="button">Last</button>
      </FullScreenDialog>
    </>,
  );

  expect(screen.getByRole('dialog', { name: 'All published posts' }))
    .toHaveFocus();
  await user.keyboard('{Escape}');
  expect(onClose).toHaveBeenCalledOnce();
});
```

Add a rerender assertion that closing the dialog restores focus to Origin, and Tab/Shift+Tab wrap between First and Last.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
npm test -- src/components/casework/FullScreenDialog.test.tsx
```

Expected: FAIL because the component does not exist.

- [ ] **Step 3: Implement the dialog shell**

Implement a fixed backdrop with:

```tsx
<section
  aria-label={label}
  aria-modal="true"
  className="relative flex h-[90vh] w-[min(90vw,1440px)] flex-col overflow-hidden rounded-2xl bg-white shadow-2xl"
  ref={dialogRef}
  role="dialog"
  tabIndex={-1}
>
```

Capture `document.activeElement` when opening, focus the dialog, listen for Escape, wrap Tab between focusable descendants, close on backdrop click, and restore the captured origin when unmounted or closed. Render a labelled Close button using the existing Lucide `X` icon.

- [ ] **Step 4: Run focused and full Admin tests**

```powershell
npm test -- src/components/casework/FullScreenDialog.test.tsx
npm test
```

Expected: all tests pass.

- [ ] **Step 5: Commit the dialog shell**

```powershell
git add -- apps/admin/src/components/casework/FullScreenDialog.tsx apps/admin/src/components/casework/FullScreenDialog.test.tsx
git commit -m "feat: add full-screen casework dialog"
```

### Task 7: Build the post carousel and review modals

**Files:**
- Create: `apps/admin/src/features/users/RecentPostsCarousel.tsx`
- Create: `apps/admin/src/features/users/AllPostsModal.tsx`
- Create: `apps/admin/src/features/users/PostDetailModal.tsx`
- Create: `apps/admin/src/features/users/PostReview.test.tsx`
- Modify: `apps/admin/src/types/admin.ts`

- [ ] **Step 1: Mirror API types and write failing UI tests**

Mirror `coverImageUrl`, `imageCount`, `commentCount`, `publishedPostCount`, `AdminCommentView`, and `AdminPostDetailView` exactly from the API.

Write tests that assert:

```tsx
expect(screen.getAllByRole('button', { name: /Open post/ })).toHaveLength(5);
expect(screen.getByRole('button', { name: 'Previous posts' })).toBeDisabled();
await user.click(screen.getByRole('button', { name: 'Next posts' }));
expect(scrollBy).toHaveBeenCalledWith({ behavior: 'smooth', left: cardWidth });
```

For See All:

```tsx
expect(screen.getByRole('dialog', { name: 'All published posts' })).toBeVisible();
expect(screen.getAllByTestId('all-post-card')).toHaveLength(8);
expect(screen.queryByRole('searchbox')).not.toBeInTheDocument();
```

For Post Detail:

```tsx
expect(screen.getByRole('dialog', { name: 'Repair guide' })).toBeVisible();
expect(screen.getByText('Full untruncated post content')).toBeVisible();
expect(screen.getByText('Comments (2)')).toBeVisible();
expect(screen.getByText('Helpful comment')).toBeVisible();
expect(screen.getByText('Creator reply')).toBeVisible();
```

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
npm test -- src/features/users/PostReview.test.tsx
```

Expected: FAIL because all three components are absent.

- [ ] **Step 3: Implement the five-post carousel**

Render only `posts.slice(0, 5)`. Use a horizontally scrolling `ref`, card-width movement, and side-positioned buttons:

```tsx
<button
  aria-label="Previous posts"
  className="absolute left-2 top-1/2 z-10 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full border border-slate-200 bg-white text-slate-700 shadow-md transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40"
  disabled={!canScrollPrevious}
  onClick={() => scroll(-1)}
  type="button"
>
  <ChevronLeft aria-hidden="true" />
</button>
```

Place the matching Next button at `right-2`. Recalculate boundary state on scroll and resize. Cards show the cover image when present and a clear text-only treatment otherwise. Card selection calls `onOpenPost(post.id)`.

- [ ] **Step 4: Implement the See All modal**

Use `FullScreenDialog` and:

```tsx
<div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
  {posts.map((post) => (
    <button
      className="overflow-hidden rounded-xl border border-slate-200 bg-white text-left transition hover:-translate-y-0.5 hover:shadow-md"
      data-testid="all-post-card"
      key={post.id}
      onClick={() => onOpenPost(post.id)}
      type="button"
    >
      {post.coverImageUrl ? (
        <img
          alt=""
          className="aspect-[4/3] w-full object-cover"
          src={post.coverImageUrl}
        />
      ) : (
        <span className="grid aspect-[4/3] w-full place-items-center bg-slate-100 text-sm font-bold text-slate-400">
          Text post
        </span>
      )}
      <span className="block p-4">
        <span className="block line-clamp-2 font-extrabold text-slate-900">
          {post.title}
        </span>
        <span className="mt-2 flex items-center justify-between text-xs font-semibold text-slate-500">
          <span>{formatDate(post.publishedAt ?? post.createdAt)}</span>
          <span>{post.commentCount} comments</span>
        </span>
        <span className="mt-2 block text-xs font-bold uppercase tracking-wide text-emerald-700">
          {post.moderationStatus}
        </span>
      </span>
    </button>
  ))}
</div>
```

Do not render search, filter, or sort controls.

- [ ] **Step 5: Implement Post Detail**

Use the same dialog shell. Render the media viewer on the left and one scrolling details column on the right. Keep `selectedImageIndex` local, render all thumbnails, full content with `whitespace-pre-wrap`, tags, date, and status. Render `Comments (N)` after the post metadata, then top-level comments and their nested replies. The UI is read-only.

- [ ] **Step 6: Run focused and full Admin tests**

```powershell
npm test -- src/features/users/PostReview.test.tsx
npm test
npm run typecheck
```

Expected: all tests and TypeScript checks pass.

- [ ] **Step 7: Commit the reusable post review UI**

```powershell
git add -- apps/admin/src/types/admin.ts apps/admin/src/features/users/RecentPostsCarousel.tsx apps/admin/src/features/users/AllPostsModal.tsx apps/admin/src/features/users/PostDetailModal.tsx apps/admin/src/features/users/PostReview.test.tsx
git commit -m "feat: add administrator post review modals"
```

### Task 8: Integrate post review into Users without redesigning it

**Files:**
- Modify: `apps/admin/src/features/users/UserDetail.tsx`
- Modify: `apps/admin/src/features/users/UsersPage.tsx`
- Modify: `apps/admin/src/features/users/UsersPage.test.tsx`

- [ ] **Step 1: Write the failing Users integration test**

Set `publishedPostCount: 12` and five recent posts on the detail fixture. Extend the API mock for `/admin/users/user-1/posts` and `/admin/posts/post-1`. Assert:

```tsx
expect(await screen.findByText('12')).toBeVisible();
await user.click(screen.getByRole('button', { name: 'Open post Repair guide' }));
expect(await screen.findByRole('dialog', { name: 'Repair guide' })).toBeVisible();
await user.click(screen.getByRole('button', { name: 'Close' }));
await user.click(screen.getByRole('button', { name: 'See all' }));
expect(api.get).toHaveBeenCalledWith('/admin/users/user-1/posts');
expect(await screen.findByRole('dialog', { name: 'All published posts' }))
  .toBeVisible();
```

Also assert that Account Decision remains visible before and after closing either modal.

Add a creator-header regression assertion:

```tsx
const identity = screen.getByTestId('user-identity');
expect(within(identity).getByLabelText('Verified content creator')).toBeVisible();
expect(within(identity).getByText('Active')).toBeVisible();
expect(within(identity).queryByText('Approved')).not.toBeInTheDocument();
```

- [ ] **Step 2: Run the focused Users test and confirm RED**

```powershell
npm test -- src/features/users/UsersPage.test.tsx
```

Expected: FAIL because UserDetail still renders static text cards and UsersPage has no modal state.

- [ ] **Step 3: Make UserDetail presentational**

Add callbacks:

```ts
type Props = {
  user: UserDetailView;
  onOpenPost: (postId: string) => void;
  onSeeAllPosts: () => void;
};
```

Keep the existing profile, fact row, spacing, colours, and Account Decision placement. Change the Published Posts fact to `user.publishedPostCount`. Replace only the Recent Published Content cards with `RecentPostsCarousel`, and place **See all** at the section header's top-right.

Give the name-and-status row `data-testid="user-identity"`. Replace the incorrect creator `StatusBadge status="approved"` beside the name with the mobile-matched verification mark. Use the existing Lucide `Check` icon inside a `16px` circular `#2F8FED` blue container, keep a `6px` gap after the name, and expose `aria-label="Verified content creator"`. Keep the account-status badge (for example, **Active**) unchanged and do not render text inside the creator mark.

- [ ] **Step 4: Add UsersPage modal state and data loading**

Track:

```ts
const [allPosts, setAllPosts] = useState<PostSummaryView[] | null>(null);
const [allPostsOpen, setAllPostsOpen] = useState(false);
const [postDetail, setPostDetail] = useState<AdminPostDetailView | null>(null);
const [postDetailId, setPostDetailId] = useState<string | null>(null);
const [postReviewError, setPostReviewError] = useState<string | null>(null);
```

Load all posts only when **See all** is selected. Load a post detail only when a card is selected. When selecting from See All, retain the all-posts collection and scroll position, hide the collection view, and restore it when Post Detail closes. Reset modal state when the selected user changes.

- [ ] **Step 5: Run focused and full Admin tests**

```powershell
npm test -- src/features/users/UsersPage.test.tsx
npm test
npm run typecheck
```

Expected: all tests and TypeScript checks pass.

- [ ] **Step 6: Commit Users integration**

```powershell
git add -- apps/admin/src/features/users
git commit -m "feat: review complete user posts in admin portal"
```

### Task 9: Update project documentation and verify the complete slice

**Files:**
- Modify: `Project_Overview.md`

- [ ] **Step 1: Update Project Overview**

Record:

- Reports now show real total reports, unique reporters, and reason percentages.
- `REPORT_REVIEW_THRESHOLD=1` is explicitly a testing convenience and must be set to `1000` before deployment.
- Overview shows the latest 15 decisions in a scrollable panel.
- Users exposes the latest-five carousel, See All modal, complete images/post fields, and approved comments.
- Creator identity uses the same blue circular check as the mobile app; **Approved** remains a content status and is not shown as a user badge.
- Mobile owner-only appeal submission and Admin appeal decisions are functionally testable.
- Gemini and AI-flagged data integration remain deferred.
- Commands must continue to run directly in the user's PowerShell environment, never in the sandbox.

- [ ] **Step 2: Run API verification directly in PowerShell**

From `services/api`:

```powershell
npm test
npm run typecheck
npm run build
```

Expected: all commands exit 0.

- [ ] **Step 3: Run Admin verification directly in PowerShell**

From `apps/admin`:

```powershell
npm test
npm run typecheck
npm run build
```

Expected: all commands exit 0. Restore only the generated `apps/admin/tsconfig.tsbuildinfo` if the build modifies it.

- [ ] **Step 4: Run the mobile appeal regression tests**

From `apps/mobile`:

```powershell
flutter test test/chat_widgets_test.dart --plain-name "post appeal"
flutter test test/chat_repository_test.dart --plain-name "appeal"
```

Expected: appeal UI and repository tests pass.

- [ ] **Step 5: Verify the live Admin Portal in the in-app browser**

Using real local API data, verify:

1. A one-report case appears and shows `100%` for its only reason.
2. Overview displays up to 15 internally scrollable decisions.
3. Users preserves its current profile and Account Decision layout.
4. A content creator has the mobile-matched blue circular check immediately after their name, while the **Active** badge remains and no identity-level **Approved** badge appears.
5. The recent carousel has controls on the row's left and right edges and contains no more than five posts.
6. Direct recent-post selection opens the large detail modal.
7. **See all** opens a four-column grid without search or filters.
8. Post Detail shows all images, full text, tags, date, status, and comments below the post details.
9. Empty, loading, retry, Escape, and focus-restoration states behave correctly.

- [ ] **Step 6: Review the final diff and commit documentation**

```powershell
git diff --check
git status --short
git add -- Project_Overview.md
git commit -m "docs: record admin review refinements"
```

Expected: no whitespace errors, no generated files staged, and only intended source/documentation changes committed.

## Plan Self-Review

- Spec coverage: Tasks 1–3 cover report and Overview requirements; Tasks 4–8 cover all Users data and interaction requirements; Task 9 covers documentation, appeal regression, and browser acceptance criteria.
- Placeholder scan: the plan contains no `TBD`, deferred implementation steps, or unspecified error-handling instructions.
- Type consistency: API and Admin both use `PostSummaryView`, `AdminCommentView`, `AdminPostDetailView`, `publishedPostCount`, `totalReports`, `listUserPosts`, and `getPost` consistently.
- Scope check: no Gemini work, AI-flagged queue integration, report-record fabrication, search/filter controls, or unrelated Admin Portal redesign is included.
