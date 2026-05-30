# CyanZone

AI-Assisted Parent-Supervised Educational Social Platform for Teenagers.

## Tech Stack

- Mobile app: Flutter
- Admin dashboard: React, TypeScript, Tailwind
- Backend service: Node.js, Express
- Backend platform: Supabase Auth, PostgreSQL, Storage, Realtime
- AI moderation: Google Perspective API

## Workspace Structure

```text
apps/
  mobile/       Flutter mobile app for teenagers, parents, and creators
  admin/        React admin dashboard
services/
  api/          Express API for AI moderation and privileged operations
supabase/
  auth.sql      Phase 3 auth trigger and admin policies
  README.md     Supabase setup guide
  schema.sql    Phase 2 database schema
  storage.sql   Phase 1 storage bucket setup
docs/
  setup.md      Local setup and demo notes
```

## Phase 1 Setup

1. Create a Supabase project.
2. Copy each `.env.example` file to `.env`.
3. Fill in Supabase URL and anon/service-role keys.
4. Run `supabase/storage.sql` in the Supabase SQL editor to create storage buckets.
5. Run `supabase/schema.sql` in the Supabase SQL editor to create database tables.
6. Run `supabase/auth.sql` in the Supabase SQL editor to enable profile auto-create.
7. Install dependencies for each app when local tooling is available.

## Applications

### Mobile

```powershell
cd apps/mobile
flutter pub get
flutter run
```

### API

```powershell
cd services/api
npm install
npm run dev
```

Create the first admin after running `supabase/auth.sql`.

If you changed `ADMIN_BOOTSTRAP_SECRET` in `.env`, restart the API first so the new value is loaded. For the most reliable bootstrap flow on Windows, run the compiled API:

```powershell
cd services/api
npm run build
node dist/server.js
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
