# Real Gemini Moderation Design

Date: 2026-09-06
Status: Approved for implementation planning

## Context

CyanZone currently stores new posts and comments directly in Supabase. The
database temporarily auto-approves new content, edited posts are reset to
`pending`, and the Admin Portal's AI-Flagged Content page uses local mock data.
`services/api` already provides the trusted Express boundary for administrator
operations and contains an optional `GEMINI_API_KEY`, but it has no member
authentication or moderation routes.

Real moderation must cover public post text, post images, edited posts, and
public comments. Private direct and group chat remain excluded. Gemini secrets
must stay server-side, and all public visibility decisions must remain
authoritative in Supabase rather than trusting a mobile or admin client.

The Express API is currently local-only. The feature will be implemented and
tested locally first, then deployed as a Vercel Express project rooted at
`services/api`.

## Goals

- Moderate every new public post, edited post, and public comment before it is
  publicly visible.
- Moderate post text and all attached post images in one authoritative flow.
- Use the maintained Google GenAI JavaScript SDK and schema-constrained JSON.
- Apply CyanZone's fixed overall-risk thresholds:
  - below 40: approve and publish;
  - 40 through 60 inclusive: keep unpublished for administrator review;
  - above 60: reject.
- Persist enough evidence to explain, audit, retry, and reproduce each decision.
- Replace the Admin Portal's local AI queue with real API-backed cases.
- Give the author a recoverable `Retry moderation` action when Gemini remains
  unavailable after one automatic retry.
- Keep the implementation compatible with stateless Vercel Functions.

## Non-goals

- Moderating private direct or group chat.
- FCM or APNs delivery. Existing in-app notification records remain the event
  foundation for the later push-delivery phase.
- Training or fine-tuning a custom moderation model.
- Automatic background workers, queues, or scheduled retry jobs for the MVP.
- Replacing administrator reports or appeals with AI decisions.
- A broad mobile, API, admin, or database refactor unrelated to moderation.
- Production-scale abuse prevention, billing controls, or moderation analytics.

## Considered Approaches

### 1. Extend the existing Express API with request-driven moderation

This is the selected approach. Mobile creates an unpublished record, then calls
an authenticated Express moderation endpoint. The API reads the authoritative
content, calls Gemini, validates the structured response, and persists the
decision. The Admin Portal reads and decides medium-risk cases through the same
trusted API.

This keeps the Gemini key and Supabase service-role key server-side, reuses the
existing administrator architecture, and deploys cleanly as a stateless Vercel
Function.

### 2. Add a database queue and continuously running worker

A worker could claim moderation jobs and retry them independently of the
client. It would be useful at larger scale, but it requires a worker host,
queue monitoring, retry scheduling, and delayed client polling. Vercel's
request-based Express deployment does not provide an always-running process, so
this is unnecessary infrastructure for the MVP.

### 3. Use a Supabase Edge Function or call Gemini from Flutter

An Edge Function would split privileged application behavior between Express
and a second backend architecture. A Flutter call would expose the Gemini key
and let an untrusted client influence the moderation result. Neither is
selected.

## Author Flow

### New post

1. Mobile creates the post with `moderation_status = pending`.
2. Mobile uploads and records all selected images.
3. Mobile calls `POST /moderation/posts/:postId` with the current Supabase
   access token.
4. The API verifies the authenticated user owns the post and claims its current
   moderation revision.
5. The API reads the title, body, tags, and ordered image records from Supabase,
   reconstructs trusted public Storage URLs from their storage paths, and sends
   the text and remote image inputs to Gemini.
6. The API validates and stores the result, applies the CyanZone threshold, and
   returns the final state to mobile.
7. Mobile reports one of: published, awaiting administrator review, rejected,
   or temporarily unavailable with `Retry moderation`.

### Edited post

Changing title, content, tags, or images increments the post's moderation
revision and resets it to unpublished `pending`. Mobile calls the same endpoint
only after all text and image changes finish. An older response cannot publish
a newer revision.

### Comment

Mobile inserts the comment as unpublished `pending`, then calls
`POST /moderation/comments/:commentId`. Comments use the same decision rules
without image input. A pending comment remains readable to its author but is
hidden from other members.

### Retry

The API makes at most two Gemini attempts during one request: the original call
and one bounded automatic retry for a retryable timeout or provider failure. If
both fail, the target remains unpublished and its case becomes `failed`.
Mobile shows `Retry moderation`, which calls the same endpoint for the same
record and revision; it never creates duplicate content.

Repeated calls for a revision that already has a final AI or administrator
decision return the stored result without calling Gemini again. A short
database-backed cooldown protects the endpoint from accidental rapid retries.

## Moderation Decision Contract

Gemini receives a versioned system instruction describing CyanZone's teenage
educational context and a response schema containing:

- overall risk score from 0 through 100;
- category scores for harassment or bullying, hate, sexual content, violence
  or dangerous behavior, self-harm, spam or scam, and privacy exposure;
- concise evidence items that identify the relevant text or visual concern
  without reproducing unnecessary harmful content;
- a concise user-safe reason;
- whether the evidence came from text, image, or both.

The API validates the response with Zod and computes the decision from the
validated overall score. Gemini does not choose CyanZone's publish status.

The model name is environment-configurable through `GEMINI_MODEL`; the initial
default is the current stable Flash model documented by Google when the feature
is implemented. Every case stores the actual model and prompt version so a
future model change does not rewrite historical evidence.

Gemini safety blocking is handled as a moderation signal rather than a network
failure. If Google returns an explicit input safety block with ratings but no
structured body, the API records those ratings, assigns overall risk 100, and
rejects the revision through the same greater-than-60 threshold. Missing,
malformed, or unsupported responses are provider failures and never cause
publication.

## Data Design

### Content status

The existing `moderation_status` remains the public visibility authority:

- `pending`: unpublished while processing, awaiting administrator review, or
  waiting for retry;
- `approved`: publicly visible;
- `rejected`: rejected by AI or an administrator;
- `removed`: removed by an administrator through an existing report flow.

New posts and comments change from temporary auto-approval to `pending` by
default. Existing approved records are not retroactively moderated.

Posts and comments gain a monotonically increasing `moderation_revision`.
Database triggers increment it and reset AI decision fields whenever moderated
content changes. Post image insertion, replacement, reordering, or removal also
invalidates the current post moderation result.

`post_images` gains a supported image MIME type recorded by mobile at upload
time. For an older row without that value, the API may infer PNG, JPEG, WEBP,
HEIC, or HEIF from its trusted storage-path extension. The API never accepts an
arbitrary image URL from a moderation request. It reconstructs the URL from the
configured Supabase project, public `images` bucket, and database-owned storage
path, preventing the moderation endpoint from becoming a server-side request
forgery proxy.

### Moderation cases

Add `content_moderation_cases` with one logical case per target revision:

- case ID, target type, target ID, owner ID, and moderation revision;
- lifecycle state: `processing`, `admin_review`, `approved`, `rejected`,
  `failed`, or `superseded`;
- overall and category risk scores;
- structured evidence and user-safe reason;
- provider, model, and prompt version;
- AI attempt count, failure code, and failure message suitable for operations;
- a per-attempt claim token and short processing lease expiry;
- AI decision source or administrator decision source;
- administrator ID, reason, and decision time when applicable;
- created, started, completed, and updated timestamps.

A unique target-type, target-ID, and revision constraint provides idempotency.
The target row keeps the final score and reason fields already used by feeds,
notifications, reports, and appeals; the case table retains the richer audit
history.

Preparing a case creates a random claim token and a 30-second processing lease.
A duplicate request received during a live lease returns the current processing
state without calling Gemini. After the lease expires, a retry may issue a new
claim token and continue the same case. Result and failure functions require the
current token, so a late response from an older Vercel invocation cannot
overwrite a reclaimed attempt.

Direct client writes to moderation authority fields are blocked. Security-
definer database functions claim a revision and apply AI or administrator
results atomically. They compare the expected revision before changing public
status. A stale result is stored as superseded and cannot publish edited
content.

Row-level security lets an author read the moderation case for their own
content and lets active administrators read all cases. Only the trusted API and
administrator decision functions may change cases or moderation decisions.

## API Architecture

### Member authentication

Add reusable member authentication middleware beside the existing
administrator middleware. It verifies the Supabase bearer token and requires
an active, non-admin profile. Ownership is checked again when loading the
moderation target.

### Moderation layers

- Router: validates target IDs, authentication, and stable HTTP responses.
- Service: owns claiming, idempotency, retry, threshold, stale-revision, and
  result-mapping rules.
- Repository: reads authoritative Supabase content and invokes transactional
  moderation functions.
- Gemini gateway: adapts Google GenAI input/output to CyanZone-owned moderation
  models and has no database or Express dependency.

This applies Adapter for the provider boundary, Strategy for the replaceable
moderation provider contract, and State for the moderation-case lifecycle. The
existing API's Router-Service-Repository separation is preserved.

### Member endpoints

- `POST /moderation/posts/:postId`
- `POST /moderation/comments/:commentId`

Successful responses return the target, revision, status, case state,
user-safe reason, score when appropriate, and whether retry is allowed. Stable
HTTP errors distinguish unauthorized access, missing content, stale content,
retry cooldown, and temporary provider failure.

### Administrator endpoints

- `GET /admin/moderation-cases`
- `GET /admin/moderation-cases/:caseId`
- `POST /admin/moderation-cases/:caseId/decision`

The list supports pending, approved, and rejected tabs and target-type filters.
Only `admin_review` cases accept a new approve or reject decision. The database
locks the case, verifies that its revision is still current, updates the target
and case together, records the existing administrator audit entry, and lets the
existing notification foundation observe the resulting target transition.

## Mobile Design

Add `API_BASE_URL` to the mobile environment and an authenticated API client
that reads the current Supabase access token. The Gemini key and service-role
key are never present in Flutter.

`PostsRepository` remains responsible for Supabase draft and image persistence.
A separate `ContentModerationGateway` owns the Express calls so provider and
transport details do not spread into pages. The create-post, edit-post, and
comment flows coordinate persistence followed by moderation and map the result
to clear feedback.

The author can retry a failed case from the relevant own-content state. A retry
uses the existing record ID. Pending administrator review does not display a
retry action because Gemini already completed successfully.

## Admin Portal Design

Replace `aiFlaggedMockData.ts` and `aiFlaggedMockAdapter.ts` with API-backed
list, detail, and decision operations using the existing authenticated
`adminApi` client. Preserve the current page layout and Pending, Approved, and
Rejected tabs rather than redesigning the portal.

Pending displays only medium-risk `admin_review` cases. The detail panel shows
the authoritative content, images, overall score, category evidence, model,
submission time, and revision. Approval may use a concise default audit reason;
rejection requires the existing 10-to-500-character administrator reason.
Completed tabs are read-only.

## Failure and Concurrency Behavior

- Gemini timeout or transient provider error: retry once within the request,
  then keep unpublished and offer user retry.
- Invalid structured response: treat as provider failure; never infer approval.
- Explicit Gemini input safety block: record the safety evidence and reject.
- Missing image, unsupported MIME type, or provider failure to read a trusted
  Storage URL: keep unpublished and report a recoverable moderation failure.
- Duplicate request for a processing revision: return the current processing
  case rather than starting a second Gemini call while its lease is live.
- Processing invocation terminated: permit a same-case retry after the
  30-second lease expires and invalidate the previous claim token.
- Duplicate request for a completed revision: return its stored result.
- Content edited during moderation: mark the old case superseded; never apply
  its result to the new revision.
- Administrator decision racing with an edit: reject the stale decision and
  refresh the case.
- Client disconnect: the Vercel invocation may finish and persist the result;
  retry remains idempotent if the client did not receive the response.
- Any unexpected exception: keep content unpublished and return a safe message
  without leaking provider, database, or credential details.

## Vercel Deployment

Create a Vercel project whose root directory is `services/api`. Export the
composed Express application through a recognized entry point while preserving
the local `npm run dev` listener. Configure at least:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ADMIN_BOOTSTRAP_SECRET`
- `REPORT_REVIEW_THRESHOLD`
- `GEMINI_API_KEY`
- `GEMINI_MODEL`

The deployed HTTPS origin becomes `VITE_API_BASE_URL` for the Admin Portal and
`API_BASE_URL` for Flutter. CORS is restricted to the deployed Admin Portal and
approved local development origins for browser calls; native mobile requests
still authenticate with Supabase bearer tokens.

The normal moderation request targets completion within 20 seconds, including
one bounded retry. No implementation depends on Vercel process memory,
background loops, or a single warm instance.

## Testing and Verification

Verification remains focused on the affected feature:

- Gemini gateway tests for text, multiple images, structured validation,
  safety blocking, timeouts, and retryable versus permanent errors.
- Service tests for all thresholds, including exactly 40 and 60, idempotency,
  cooldown, stale revisions, and retry behavior.
- Router tests for member authentication, ownership, stable responses, and
  administrator authorization.
- Repository and SQL contract tests for case uniqueness, field protection,
  revision invalidation, transactional decisions, RLS, audit, and notification
  transitions.
- Mobile tests for new post, edited post, comment, all four outcomes, and retry
  without duplicate records.
- Admin tests proving the AI page performs authenticated API reads and writes,
  renders real evidence, validates rejection reasons, and no longer imports
  mock data.
- API type-check, test, and build; scoped Flutter tests and analysis; Admin
  tests, type-check, and build.
- Manual local integration with a real Gemini key, then physical-device testing
  against the deployed HTTPS API.

## Manual Configuration Handoff

After implementation, provide exact instructions for:

1. creating or selecting a Google AI Studio API key;
2. setting local `services/api/.env` values without committing secrets;
3. running the new idempotent Supabase moderation SQL in the SQL Editor;
4. configuring and deploying the `services/api` Vercel project;
5. adding the deployed API URL to Admin Portal and Flutter environments;
6. confirming `/health`, one safe post, one medium-risk review case, one
   rejected case, one image case, and one provider-failure retry.

## Acceptance Criteria

- New and edited public content never becomes visible before a current-revision
  decision.
- Safe content below 40 publishes automatically.
- Scores from 40 through 60 remain unpublished and appear in the real Admin
  Portal queue.
- Scores above 60 are rejected with a user-safe reason.
- Text and every post image are included in the post decision.
- Comments use the same thresholds and remain hidden until approved.
- Failed provider calls never publish content and can be retried without
  creating duplicates.
- Old Gemini results cannot publish a post edited during moderation.
- Administrator approval or rejection is transactional, authorized, audited,
  and visible in the completed tabs.
- Gemini and Supabase service-role secrets exist only in the backend
  environment.
- The API remains locally runnable and deployable to Vercel.
