# Gemini Moderation Hardening Design

Date: 2026-09-07
Status: Approved by the request to fix the completed audit findings

## Goal

Close the security, reliability, and deployment gaps found in the first real
Gemini moderation implementation without redesigning CyanZone or adding a
background job system.

## Decisions

### Database and Storage Are the Authority

Authenticated inserts cannot choose moderation authority fields. New posts and
comments are forced to revision 1, `pending`, unpublished, and without AI or
administrator evidence. Update protection remains in place. Every
security-definer helper that is not a client API loses `PUBLIC`, `anon`, and
`authenticated` execute permission.

The shared `images` bucket keeps its current public-read behavior for this MVP,
because changing it to private storage would require signed-URL changes across
posts, chat, and administration. Writes are tightened: post paths must begin
with the member ID, chat paths must use `chat/<member-id>/...`, deletes are
owner-scoped, and direct object updates are disabled. CyanZone already creates
unique object names with `upsert: false`, so object updates are unnecessary.

### Gemini Errors Fail Closed Without False Rejection

`gemini-3.8-flash` remains the default. Google lists it as a stable model as of
2026-09-02, so the earlier audit conclusion that the model did not exist is no
longer valid.

Only an explicit safety-block signal becomes an automatic score-100 rejection.
A generic HTTP 400, malformed response, unsupported request, timeout, or SDK
error becomes a provider failure and leaves the content unpublished. When
Google supplies safety ratings, CyanZone maps the blocked categories into its
stored category scores and records that the block came from text, image, or
both when the provider exposes that information. It does not claim that every
category scored 100.

### API Deployment Is Explicit

The Express application gains a Vercel `/api/index.ts` entry and a rewrite that
sends all routes to it. Browser CORS accepts only configured origins. Requests
without an `Origin` header continue to work for the native Flutter app and
server-to-server tests. Deployment configuration uses a comma-separated
`CORS_ALLOWED_ORIGINS` variable.

### Mobile Failures Are Typed and Retry the Same Record

Timeouts, socket failures, and `http.ClientException` are converted to a
retryable `ContentModerationFailure`. Dependency construction receives the API
base URL explicitly, so tests and alternative entry points do not depend on
global dotenv state.

The persistence call and moderation call remain separate. After a record is
created, any moderation retry uses the returned post/comment ID and never
creates a replacement record. A lightweight local retry store retains failed
target IDs across app restarts. A small pending-moderation surface lets the
author retry those same targets; successful, rejected, or administrator-review
results remove the item.

### Historical Admin Cases Use Snapshots

Each moderation case stores a JSON snapshot of the target text, tags, and image
references when the revision is claimed. Admin list/detail hydration prefers
that snapshot, with a live-row fallback for cases created before this migration.
This prevents an old decision from displaying newer content. Existing in-memory
search remains acceptable for the UAT-sized MVP; production-scale server-side
search and cursor pagination are documented as a future optimization rather
than mixed into this security fix.

## Testing

- SQL contract tests cover insert forcing, helper revokes, snapshot creation,
  and owner-scoped immutable storage objects.
- Gemini gateway/service tests distinguish generic 400 errors from explicit
  safety blocks and preserve supplied ratings.
- API tests cover configured CORS and the Vercel entry contract.
- Flutter tests cover socket/client/timeout mapping, explicit dependency
  configuration, retry persistence, and same-ID retry orchestration.
- Admin repository tests cover historical snapshot hydration.
- Run full API, Admin Portal, and mobile test/typecheck/analyze/build checks.

## Manual Boundary

Code changes do not create a Google key, apply SQL to the live Supabase project,
or deploy Vercel. The final handoff supplies exact dashboard steps after local
verification. Secrets are never committed.

