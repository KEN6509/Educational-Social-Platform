# CyanZone

AI-Assisted Parent-Supervised Educational Social Platform for Teenagers.

## Tech Stack

- Mobile app: Flutter
- Admin dashboard: React, TypeScript, Tailwind
- Backend service: Node.js, Express
- Backend platform: Supabase Auth, PostgreSQL, Storage, Realtime
- AI moderation: Google Gemini for public text and image posts/comments

## Workspace Structure

```text
apps/
  mobile/       Flutter mobile app for teenagers, parents, and creators
  admin/        React admin dashboard
services/
  api/          Express API for privileged operations and Gemini moderation
supabase/
  auth.sql      Phase 3 auth trigger and admin policies
  README.md     Supabase setup guide
  schema.sql    Phase 2 database schema
  storage.sql   Phase 1 storage bucket setup
docs/
  setup.md      Local setup and demo notes
```

## Initial Setup

1. Create a Supabase project.
2. Copy each `.env.example` file to `.env`.
3. Fill in Supabase URL and anon/service-role keys.
4. Run `supabase/storage.sql` in the Supabase SQL editor to create storage buckets.
5. Run `supabase/schema.sql` in the Supabase SQL editor to create database tables.
6. Run `supabase/auth.sql` in the Supabase SQL editor to enable profile auto-create.
7. Apply the incremental SQL required by current modules, especially
   `follow.sql`, `comment_mentions.sql`, `chat.sql`, `parent_supervision.sql`,
   `registration_consent_otp.sql`, `admin_portal.sql`, and
   `ai_moderation.sql`; see `docs/setup.md` for the complete order.
8. Install dependencies for each app when local tooling is available.

## Applications

### Mobile

```powershell
cd apps/mobile
flutter pub get
flutter run
```

The mobile app currently includes the educational feed, post creation/detail,
profiles/search, parent-child foundations, direct/group chat, chat media and
shared posts, Activity/New Followers, unread badges, and offline-oriented media
caching. See `Project_Overview.md` for the current code-level handoff.

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
or source control. Health and admin-bootstrap routes do not call Gemini.

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

## Current Implementation Boundary

- Supabase-backed in-app chat notifications and badges are implemented.
- External Android/iOS push delivery is not implemented yet.
- Gemini text/image moderation is connected through the privileged API and the
  mobile/Admin clients. Failed requests are retained for same-record retry,
  and administrator cases preserve the submitted content revision. Live
  Supabase migration, Gemini key/Vercel environment setup, and final acceptance
  evidence are still required.
- Chat is intentionally excluded from AI moderation.
- Parent-child linking and supervision flows remain incomplete and are a next
  implementation priority.
