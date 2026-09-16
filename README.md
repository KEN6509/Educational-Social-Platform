# CyanZone

AI-Assisted Parent-Supervised Educational Social Platform for Teenagers.

## Tech Stack

- Mobile app: Flutter
- Admin dashboard: React, TypeScript, Tailwind
- Backend service: Node.js, Express
- Backend platform: Supabase Auth, PostgreSQL, Storage, Realtime
- AI moderation: Google Gemini for public text and image posts/comments
- Android push notifications: Firebase Cloud Messaging
- Deployment: Vercel for the API and Administration Portal

## Workspace Structure

```text
apps/
  mobile/       Flutter mobile app for teenagers, parents, and creators
  admin/        React admin dashboard
services/
  api/          Express API for privileged operations and Gemini moderation
supabase/
  auth.sql      Authentication triggers and administrator policies
  README.md     Supabase setup guide
  schema.sql    Canonical database schema
  storage.sql   Storage bucket setup
docs/
  setup.md                Complete setup and deployment guide
  Future_Improvements.md  Deferred post-MVP improvements
Project_Overview.md       Current implementation and SRS handover
```

## Initial Setup

1. Create a Supabase project.
2. Copy each `.env.example` file to `.env`.
3. Fill in Supabase URL and anon/service-role keys.
4. Run `supabase/storage.sql` in the Supabase SQL editor to create storage buckets.
5. Run `supabase/schema.sql` in the Supabase SQL editor to create database tables.
6. Run `supabase/auth.sql` in the Supabase SQL editor to enable profile auto-create.
7. Apply the incremental SQL required by current modules in the exact order in
   [`docs/setup.md`](docs/setup.md). Git and Vercel deployments do not apply
   Supabase SQL.
8. Install dependencies for each app when local tooling is available.

## Applications

### Mobile

```powershell
cd apps/mobile
flutter pub get
flutter run
```

The mobile app includes the educational feed, moderated posts/comments,
profiles/search, Parent Supervision, direct/group chat, Android push and in-app
notifications, safety Check-In/SOS, and offline-oriented media caching. See
[`Project_Overview.md`](Project_Overview.md) for the current implementation
handover.

### API

```powershell
cd services/api
npm install
npm run dev
```

The moderation routes require `GEMINI_API_KEY` in the Express API environment.
The default moderation chain uses `gemini-3.5-flash-lite` first and makes one
`gemini-3.8-flash` fallback call after an HTTP 429 or 503. Other retryable
transport failures return a retryable error without duplicating the provider
call; safety and permanent failures stop immediately. Each provider call has a
15-second timeout. `GEMINI_MODEL`, `GEMINI_FALLBACK_MODEL`, and
`GEMINI_TIMEOUT_MS` are optional overrides. Keep all Gemini credentials
server-side; never put them in Flutter, React, Supabase client configuration,
or source control. Firebase service-account values, webhook secrets, the
Supabase service-role key, and `CRON_SECRET` are also API-only. Health and
admin-bootstrap routes do not call Gemini.

Create the first admin after running `supabase/auth.sql`.

If you changed `ADMIN_BOOTSTRAP_SECRET` in `.env`, restart the API first so the new value is loaded. For the most reliable bootstrap flow on Windows, run the compiled API:

```powershell
cd services/api
npm run build
node dist/src/server.js
```

Then open another PowerShell window and run:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:4000/admin/bootstrap `
  -Headers @{ "x-bootstrap-secret" = "your-ADMIN_BOOTSTRAP_SECRET-value" } `
  -ContentType "application/json" `
  -Body '{"email":"admin@example.com","password":"ChangeMe123!","name":"CyanZone Admin"}'
```

The bootstrap endpoint works only while no admin profile exists.

### Admin

```powershell
cd apps/admin
npm install
npm run dev
```

## Demo Priority

CyanZone prioritizes a polished prototype over broad unfinished scope:

- Parent-child supervision
- AI-assisted moderation
- Educational Rednote-style feed
- Admin creator approval and moderation workflow

## MVP Delivery Status

- Mobile, Administration Portal, API, Supabase, Gemini moderation, Android FCM,
  Parent Supervision, and Vercel implementation/configuration are complete for
  the current MVP scope.
- The Administration Portal and API deployments report Ready. The current
  database migrations, including former-link Parent Supervision history access,
  have been applied.
- Android FCM physical-device UAT and the wider functional/non-functional
  acceptance record remain before final submission. iOS/APNs is a future
  improvement.
- Chat is intentionally excluded from AI moderation.
- The temporary two-follower creator threshold and test-only
  `REPORT_REVIEW_THRESHOLD=1` must be reviewed before a production release.
