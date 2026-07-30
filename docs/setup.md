# CyanZone Setup Notes

## Required Accounts

- Supabase project
- Google AI Studio or Google Cloud access for Gemini when AI moderation is implemented

Gemini moderation is planned for both text and images, but it is not connected
yet. The current application can run without a Gemini API key.

## Supabase Connection Values

Find these in Supabase project settings:

- Project URL
- Public anon key
- Service role key

Use the anon key in Flutter and React. Use the service role key only in the Express API.

Future Gemini credentials must also be stored only in the Express API
environment.

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
9. `supabase/admin_portal.sql`

The latest `chat.sql` is required for group-chat mentions. Run it manually in
the Supabase SQL Editor after updating the application. It creates
`chat_message_mentions` and the mention fetch/visit RPCs. Inspect any SQL Editor
error before rerunning the script.

`admin_portal.sql` must run after `chat.sql`. It creates the administrator audit
table, duplicate unresolved-report guard, administrator appeal access, and the
transactional RPCs used for account, creator, request, report, and appeal
decisions. Inspect and resolve any SQL Editor error before using the portal.

Inspect the remote schema before rerunning scripts. Notification trigger changes
do not backfill old Activity/New Followers rows.

## Current Notification Boundary

- In-app notification rows, unread dots, and badges use Supabase.
- External FCM/APNs push delivery is deferred to the next notification phase.
- Chat messages are not sent to Gemini moderation.
- `GEMINI_API_KEY` remains optional until post/comment moderation is connected.

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
REPORT_REVIEW_THRESHOLD=3
```

`REPORT_REVIEW_THRESHOLD` counts unique reporters per post/comment target. Keep
it at `3` for the approved SRS behavior unless the SRS and project overview are
revised together.

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

The Admin Portal requires an authenticated active administrator. Apply
`admin_portal.sql` before testing real casework. The AI-Flagged Content page is
the only mock-backed portal feature until Gemini integration; it does not read
or write Supabase.
