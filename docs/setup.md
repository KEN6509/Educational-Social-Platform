# CyanZone Setup Notes

## Required Accounts

- Supabase project
- Google AI Studio or Google Cloud access for the Gemini API

Gemini moderation is connected for public posts, edited posts, and public
comments. Private chat is intentionally excluded.

## Supabase Connection Values

Find these in Supabase project settings:

- Project URL
- Public anon key
- Service role key

Use the anon key in Flutter and React. Use the service role key only in the Express API.

Gemini credentials must also be stored only in the Express API environment.

## Storage Buckets

Run these files in the Supabase SQL editor in order:

1. `supabase/storage.sql`
2. `supabase/schema.sql`
3. `supabase/auth.sql`

Storage setup creates:

- `avatars`: public profile pictures
- `images`: public post and chat images

Storage policies are intentionally prototype-oriented. Verify the deployed
policies before production use. Post deletion, image-message unsend, and final
group cleanup depend on the latest storage/chat SQL behavior.

## Database Script Order

After the base storage/schema/auth scripts, apply the incremental scripts needed
by the current mobile app. At minimum, the live project should include:

1. `supabase/search.sql`
2. `supabase/tags.sql`
3. `supabase/follow.sql`
4. `supabase/post_interactions.sql`
5. `supabase/post_editing.sql`
6. `supabase/comment_moderation.sql`
7. `supabase/comment_mentions.sql`
8. `supabase/chat.sql`
9. `supabase/parent_supervision.sql`
10. `supabase/registration_consent_otp.sql`
11. `supabase/admin_portal.sql`
12. `supabase/report_flow_simplification.sql` for an existing database only
13. `supabase/ai_moderation.sql`

The latest `chat.sql` is required for group-chat mentions and current System
notifications. Run it manually in the Supabase SQL Editor after updating the
application. It creates `chat_message_mentions`, the mention fetch/visit RPCs,
and system triggers for verified creator awards, rejected posts, and posts
moving specifically from `pending` to `approved`. The last transition sends the
author a successful-publication notification without duplicating the separate
approved-appeal notification. Inspect any SQL Editor error before rerunning the
script.

`admin_portal.sql` must run after `chat.sql`. It creates the administrator audit
table, duplicate unresolved-report guard, administrator appeal access, and the
transactional RPCs used for account, creator, request, report, and appeal
decisions. Inspect and resolve any SQL Editor error before using the portal.

`ai_moderation.sql` must run after `admin_portal.sql` for an existing project.
It creates the moderation-case table, revisioned result storage, RLS, and the
service-role preparation/result/decision RPCs used by the Express API. Run the
complete file; do not copy only one function. Fresh projects still need the
incremental file so the RPCs, policies, and indexes are present.

Fresh projects use the simplified report schema already present in `schema.sql`
and `admin_portal.sql`. For an existing database that still has Open/Reviewing
report states or a report description column, inspect and then manually run
`report_flow_simplification.sql` after `admin_portal.sql`. It converts unresolved
rows to `pending_review`, replaces the report-status enum, drops the description
column, and recreates the report decision function. The repository script is not
applied to a live project automatically.

Inspect the remote schema before rerunning scripts. Notification trigger changes
do not backfill old Activity/New Followers rows.

## Current Notification Boundary

- In-app notification rows, unread dots, and badges use Supabase.
- Creator assignment/removal, rejected posts, Pending-to-Approved publication,
  reported-content removal, and both appeal outcomes have in-app notification
  foundations. Retaining reported content intentionally sends no notification.
- External FCM/APNs push delivery is deferred to the next notification phase.
- Chat messages are not sent to Gemini moderation.
- `GEMINI_API_KEY` is required by the API moderation routes and must remain
  server-side. `gemini-3.8-flash` is the current stable default;
  `GEMINI_MODEL` and `GEMINI_TIMEOUT_MS` are optional API overrides.

## Local Tooling

Install these locally for development:

- Flutter SDK
- Node.js LTS with npm
- Git

The current scaffold is generator-free and can be opened directly in an editor.

## Local Environment

Administration Portal (`apps/admin/.env`):

```text
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
VITE_API_BASE_URL=http://localhost:4000
```

Privileged API (`services/api/.env`):

```text
PORT=4000
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
ADMIN_BOOTSTRAP_SECRET=replace-with-long-random-secret
REPORT_REVIEW_THRESHOLD=1
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-3.8-flash
GEMINI_TIMEOUT_MS=8500
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

`REPORT_REVIEW_THRESHOLD` counts unique reporters per post/comment target.
Local functional testing deliberately uses `1` so the three available test
accounts can exercise the complete report-review flow. Set it to `1000` before
production deployment; the lower value is a testing convenience only.

## Local Development and Verification

Run commands directly in the user's PowerShell environment, outside the Codex
sandbox:

```powershell
cd services/api
npm run dev

cd ../../apps/admin
npm run dev -- --host 127.0.0.1 --port 4173
```

In separate PowerShell sessions, verify:

```powershell
cd apps/admin
npm test
npm run typecheck
npm run build

cd ../../services/api
npm test
npm run typecheck
npm run build

cd ../../apps/mobile
flutter test --reporter compact
flutter analyze
```

The Admin Portal requires an authenticated active administrator. Apply the
appropriate SQL sequence before testing real casework. AI-Flagged Content now
reads and writes real moderation cases through the privileged API.

## Vercel deployment

Deploy the Express API and Admin Portal only after the local checks pass:

1. Import the GitHub repository into Vercel.
2. Create an API project with root directory `services/api`. Vercel should use
   the Express entry point; no static output directory is needed.
3. Add `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_BOOTSTRAP_SECRET`,
   `REPORT_REVIEW_THRESHOLD`, `GEMINI_API_KEY`, `GEMINI_MODEL`,
   `GEMINI_TIMEOUT_MS`, and `CORS_ALLOWED_ORIGINS` to the Preview and Production
   environments. Set `CORS_ALLOWED_ORIGINS` to a comma-separated exact list,
   for example `https://<admin-domain>,http://localhost:5173,http://127.0.0.1:5173`.
4. Deploy and verify `https://<api-domain>/health` returns a healthy response.
5. Create the Admin project with root directory `apps/admin`. Set
   `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_API_BASE_URL` to the
   deployed API origin, then build/redeploy it.
6. Set `API_BASE_URL=https://<api-domain>` in `apps/mobile/.env` before the
   release build. Do not add a trailing route such as `/moderation`.

Never put the service-role key or Gemini key in Admin/mobile variables. After
deployment, verify one approved, one administrator-review, one rejected, and
one retry/failure moderation path with test content; also verify that the
Supabase moderation rows and Admin decision remain linked.

For the real-provider smoke test, create four new records rather than reusing
old IDs: one clearly safe post, one borderline post expected to enter Admin
review, one clearly disallowed test post, and one public comment. Confirm that:

- the API responds within the configured client budget;
- safe content becomes published, borderline content appears under
  AI-Flagged Content, and rejected content stays unpublished;
- a temporary network/provider failure leaves the same target available for
  Retry after an app restart instead of creating a second post/comment; and
- the Admin detail still shows the submitted snapshot after the target is
  edited to a later revision.

## Live SQL and deployment verification

This means checking the deployed Supabase objects and deployed API, not checking
whether chat history is consistent. In the Supabase SQL Editor, confirm
`content_moderation_cases` exists, the four moderation RPCs exist, RLS/policies
are enabled, and the API can create a case. In Vercel, confirm `/health`, an
authenticated moderation request, and an Admin decision. Repository tests prove
the code contract only; they cannot prove the hosted database or environment
variables are current.
