# Admin Moderation Retention and Reliability Design

## Goal

Finish the administrator moderation workflow without reopening the wider mobile
or Admin architecture. The completed moderation tabs must represent
administrator decisions, images must be reviewable without cropping, rejected
media must follow the agreed seven-day lifecycle, and intermittent Admin reads
must fail less disruptively and produce useful server-side evidence.

## Scope

This change covers:

- the AI-Flagged Content Pending, Approved, and Rejected queues;
- complete and enlarged image review with a safe unavailable state;
- seven-day retention for posts rejected by an administrator;
- a secured, idempotent daily cleanup endpoint;
- bounded Admin read retry, stale-data presentation, request ordering, request
  timing, and safe server logging;
- deployment documentation for the cleanup secret and API region.

It does not introduce a new client state-management library, read replicas,
microservices, a mobile-wide performance rewrite, or permanent copies of
rejected image files. Mobile performance will be measured during UAT before any
further optimization is selected.

## Current Problems and Causes

1. The Approved and Rejected queries filter only by moderation case state.
   Gemini automatically completed cases therefore appear beside administrator
   decisions.
2. Completed cases store an immutable target snapshot. When an image is later
   removed or replaced, its snapshot URL can point to an object that no longer
   exists. The Admin UI renders a broken image instead of an explicit state.
3. The Admin image class uses `aspect-square object-cover`, which crops valid
   portrait and landscape evidence.
4. `delete_old_rejected_posts()` only changes a post to `removed`; it does not
   delete the post row or the physical Storage object.
5. An AI queue read requires authentication lookups followed by the case query
   and several hydration queries. Serverless startup and regional latency can
   amplify this request chain after idle periods.
6. Admin routes return a safe generic error but do not currently record enough
   server-side context to distinguish a cold start, network failure, query
   error, or timeout.
7. The AI-Flagged page always assigns `empty` after a successful load and does
   not protect the current tab from an older request completing later.

## Queue Semantics

- **Pending** selects moderation cases whose state is `admin_review`.
- **Approved** selects cases whose state is `approved` and whose
  `decision_source` is `admin`.
- **Rejected** selects cases whose state is `rejected` and whose
  `decision_source` is `admin`.
- Gemini-auto-approved and Gemini-auto-rejected cases remain in the database
  for processing history but do not appear in the completed administrator
  queues.
- Completed cases remain read-only.

The `decision_source` condition is applied in the database before pagination so
page totals and page contents remain correct.

## Moderation Image Review

- Each image is placed in a bounded neutral review stage and rendered with
  `object-contain`; the full image remains visible at every aspect ratio.
- Selecting an image opens an accessible large preview that can be closed by a
  close button, the Escape key, or the backdrop.
- An image load error replaces only that image with **Image no longer
  available**. It does not fail the whole moderation case.
- Snapshot title, text, tags, evidence, scores, administrator decision, reason,
  and timestamps remain available even when historical media is unavailable.
- Historical media is not copied into a second evidence bucket. This keeps
  storage bounded.

## Rejected Post Lifecycle

An administrator rejection starts a seven-day retention window based on the
case completion time.

### Unedited rejected post

If the current post still has the same moderation revision and remains rejected
after seven days:

1. read its current `post_images` storage paths;
2. remove those objects through the Supabase Storage API;
3. delete the post row only after media removal succeeds;
4. allow existing foreign-key cascades to remove dependent post data;
5. retain the moderation case as a reduced audit record;
6. keep the rejected title, text, tags, evidence, scores, administrator,
   decision reason, and timestamps, but remove image URLs and storage paths from
   `target_snapshot`.

### Edited post

Editing creates a new moderation revision. The old administrator decision stays
as history and continues to show the old title and text. Cleanup of the old case
must never delete the newer post revision or an image still referenced by it.
An old image removed during editing is not copied or retained; the historical
case shows the unavailable state.

### User-deleted post

User deletion continues to remove current image objects immediately. The old
administrator decision remains as a small text-based audit record. Missing
historical images use the unavailable state instead of a broken element.

### Cleanup safety

- The cleanup endpoint processes a bounded batch of administrator-rejected
  post cases at least seven days old.
- It rechecks the current post ID, revision, and status immediately before
  deletion.
- Storage deletion uses the supported Storage API, never direct SQL changes to
  `storage.objects`.
- If media deletion fails, the post and snapshot are left intact so the next
  daily run can retry safely.
- Already-deleted posts and already-redacted snapshots are treated as success.
- Comment cases are not part of the rejected-post media cleanup.

## Scheduled Cleanup

The API exposes a GET maintenance endpoint invoked once daily by Vercel Cron.
It accepts only `Authorization: Bearer <CRON_SECRET>` and does not reuse Admin or
member authentication. `CRON_SECRET` must be a new random value stored only in
the API Vercel project.

The endpoint returns aggregate counts only. It never returns post content,
storage paths, secrets, or raw database errors. Each run logs its request ID,
duration, processed count, deleted count, skipped count, and failed count.

Vercel does not retry failed cron invocations, so the operation is idempotent
and any failed item remains eligible for the next daily run.

## Admin Read Reliability

### Client behaviour

- Cache queue results separately for each status.
- When a previously loaded status refreshes, keep its rows visible and show a
  small refreshing state instead of replacing the page with an empty screen.
- Retry an idempotent GET once after a short bounded delay for a network error,
  HTTP 500, 502, 503, or 504.
- Never retry 400, 401, 403, 404, or 409 responses automatically.
- Apply a bounded request timeout and preserve the existing explicit **Try
  again** action when both attempts fail.
- Use a monotonically increasing request generation so an older request cannot
  overwrite a newer tab selection.
- Correct the successful load state so non-empty results are represented as
  loaded rather than `empty`.

### Server behaviour

- Assign or propagate a request ID for every API request and return it in an
  `X-Request-Id` response header.
- Log route, method, response status, duration, request ID, and a safe internal
  error category for failed Admin requests.
- Do not log authorization headers, secrets, request bodies, post content, image
  paths, or personal profile data.
- Continue returning the existing safe user-facing errors; PostgreSQL,
  Supabase, stack-trace, and provider details remain server-side.

### Region alignment

Before setting a Vercel function region, verify the actual Supabase project
region in the Supabase dashboard. Configure the API to one matching or nearest
Vercel region and document the chosen value. Do not guess the database region.
Static Admin files remain globally delivered by Vercel.

## Testing

Automated coverage will verify:

- completed queries require `decision_source = 'admin'` before pagination;
- Gemini-only completed cases are excluded;
- image stages use contained rendering and expose a load-error fallback;
- the enlarged preview opens and closes accessibly;
- cleanup rejects missing or invalid Cron authorization;
- cleanup deletes only an unchanged, currently rejected administrator case
  after seven days;
- edited, approved, pending, Gemini-only, and younger cases are skipped;
- storage failure prevents database deletion and remains retryable;
- successful cleanup deletes the post and redacts only image metadata from the
  audit snapshot;
- GET retry rules, timeout behaviour, per-tab stale data, and latest-request
  ordering;
- safe request IDs and logging without leaking raw errors to API clients.

Manual verification will cover portrait, landscape, missing, edited, deleted,
and unedited rejected images; an idle-first-load followed by an immediate
retry; Vercel Cron authorization; and the deployed Admin/API smoke paths.

## Deployment and Operations

- Add `CRON_SECRET` to the API Vercel project, not the Admin project.
- Deploy the API cron configuration only after the endpoint and authorization
  tests pass.
- Verify the Supabase project region before adding the Vercel `regions` value.
- Observe Vercel request timing/error logs during smoke testing and UAT.
- Do not upgrade Supabase compute based only on perceived slowness. Consider it
  only if the new timing evidence shows database resource pressure after query
  and region corrections.

## References

- Supabase requires physical objects to be deleted through the Storage API:
  https://supabase.com/docs/guides/storage/management/delete-objects
- Vercel Cron configuration, security, and retry behaviour:
  https://vercel.com/docs/cron-jobs/manage-cron-jobs
- Vercel function region configuration:
  https://vercel.com/docs/project-configuration/vercel-json
- Supabase project regions:
  https://supabase.com/docs/guides/platform/regions
