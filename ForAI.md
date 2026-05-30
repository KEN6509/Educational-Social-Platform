# CyanZone Project Handover Document

## 1. Project Overview

**Project Name:** CyanZone

**Full Title:**  
AI-Assisted Parent-Supervised Educational Social Platform for Teenagers

**Core Philosophy:**
- Build a polished, demoable, presentation-ready Final Year Project prototype.
- Prioritize a complete and stable prototype over an ambitious but unfinished system.
- Main uniqueness:
  - Parent-child supervision
  - AI-assisted moderation
  - Educational social feed
- Mobile-first for real users.
- Web dashboard only for admins.

**Fixed Tech Stack:**
- Mobile App: Flutter
- Admin Dashboard: React + TypeScript + Tailwind CSS
- Backend API: Node.js + Express
- Backend Platform: Supabase
  - Supabase Auth
  - Supabase PostgreSQL Database
  - Supabase Storage
  - Supabase Realtime
- Supabase JS Client: `@supabase/supabase-js`
- AI Moderation: Google Perspective API
- Storage:
  - Profile pictures
  - Post images

## 2. Important User Role Rules

- All users start as normal users.
- There is no role selection during registration.
- Content Creator:
  - A normal user can request creator status.
  - Admin approves the request.
  - Approval sets `is_content_creator = true`.
- Parent / Child:
  - Not selected during registration.
  - Determined only through records in `parent_child_links`.
- Admin:
  - Special role for the web dashboard.
  - First admin is created through a secure backend bootstrap endpoint.

## 3. Current Workspace Structure

Main workspace:

```text
C:\Chan Ming Jiang\Degree\Sem 5\CyanZone
```

Project structure:

```text
apps/
  mobile/       Flutter mobile app
  admin/        React + TypeScript + Tailwind admin dashboard

services/
  api/          Node.js + Express backend API

supabase/
  storage.sql   Storage bucket setup
  schema.sql    Database schema
  auth.sql      Auth trigger and admin policies

docs/
  setup.md      Setup notes
```

## 4. Phases Completed

## Phase 1: Project Setup

Completed.

What was done:
- Created monorepo-style project structure.
- Created Flutter mobile app under:

```text
apps/mobile
```

- Created React admin dashboard under:

```text
apps/admin
```

- Created Node.js + Express API under:

```text
services/api
```

- Created Supabase setup folder under:

```text
supabase
```

- Added `.env.example` files for:
  - Flutter mobile
  - React admin
  - Express API
- Added real local `.env` files during development.
- Added Supabase client initialization:
  - Flutter uses Supabase anon key.
  - React admin uses Supabase anon key.
  - Express API uses Supabase service-role key.
- Created Supabase Storage setup SQL:

```text
supabase/storage.sql
```

Storage buckets:
- `avatars`
- `post-images`

The user has already run `storage.sql` successfully in Supabase SQL Editor.

Verification completed:
- Flutter project generated successfully.
- Flutter dependencies resolved.
- Flutter app tested and works.
- Admin website tested and works.
- API dependencies installed.
- Admin dependencies installed.

## Phase 2: Database Design

Completed.

Created:

```text
supabase/schema.sql
```

The user has already run this file successfully in Supabase SQL Editor.

Tables created:
- `profiles`
- `content_creator_requests`
- `posts`
- `post_images`
- `comments`
- `likes`
- `saves`
- `reports`
- `parent_child_links`
- `screen_time_logs`
- `check_ins`
- `sos_alerts`

Other database work completed:
- PostgreSQL enum types
- Primary keys and foreign keys
- Unique constraints
- Check constraints
- Indexes
- `updated_at` trigger function
- Row Level Security enabled
- Starter RLS policies
- Realtime publication setup for key tables

The user ran the verification queries and confirmed:
- Expected tables exist.
- RLS is enabled.
- Results matched expectations.

## Phase 3: Authentication

Completed.

Created:

```text
supabase/auth.sql
```

The user has already run this file successfully in Supabase SQL Editor.

What `auth.sql` does:
- Adds an `auth.users` trigger.
- Automatically creates a row in `profiles` after Supabase signup.
- Adds admin helper logic.
- Adds admin RLS policies for:
  - Creator requests
  - Reports
  - Posts
  - Comments
  - Profiles

Flutter authentication work completed:
- Added basic auth gate.
- Added login/register UI.
- Registration fields:
  - Email
  - Password
  - Confirm Password
  - Name
- No role selection during registration.
- Signed-out users see auth screen.
- Signed-in users enter the main app shell.
- Sign-out button added.

Important Flutter files:

```text
apps/mobile/lib/src/features/auth/presentation/auth_gate.dart
apps/mobile/lib/src/features/auth/presentation/auth_page.dart
apps/mobile/lib/src/app.dart
apps/mobile/lib/src/features/shell/presentation/main_shell.dart
```

Backend authentication/admin work completed:
- Added secure first-admin bootstrap endpoint:

```text
POST /admin/bootstrap
```

Important backend file:

```text
services/api/src/routes/admin.ts
```

- First admin account has already been created successfully.
- Bootstrap endpoint works only when no admin profile exists.

Important note:
- The correct bootstrap flow is documented in `README.md`.
- The reliable Windows method was:
  - Build API
  - Start compiled API with `node dist/server.js`
  - Run bootstrap request from another PowerShell window

Verification completed:
- `flutter analyze` passed.
- `flutter test` passed.
- API `npm run typecheck` passed.
- API `npm run build` passed.
- Admin `npm run build` passed.

## 5. Current Status

We have just finished Phase 3.

The project is now ready to begin:

# Phase 4: Core Mobile App Features

The auth foundation is done, but the complete user-facing mobile experience still needs to be built and polished in Phase 4.

## 6. Mindset and Plan for Remaining Phases

## Phase 4: Core Mobile App Features

Main goal:
Build the actual demoable Flutter mobile app experience.

Required features:
- Bottom navigation with 5 icons and no text:
  - Home
  - Parent-Child
  - Create
  - Chats
  - Profile
- Home Feed:
  - 2-column Rednote-style layout
  - Educational posts
  - Image-first card design
  - Smooth mobile-first UI
- Post Creation:
  - Title
  - Content
  - Tags
  - Max 9 images
  - Upload images to Supabase Storage
  - Insert post and post image records into Supabase
- Post Detail Page:
  - Multiple images
  - Title/content/tags
  - Like/dislike
  - Save
  - Comment
  - Report
- Parent-Child:
  - Linking flow
  - Show linked parent/child status
  - Screen time logs
  - Check-ins
  - SOS alerts
- Profile Page:
  - User info
  - Posted tab
  - Saved tab
  - Liked tab
  - Sign out
- Branding:
  - App name is CyanZone.
  - Top bar should use logo image instead of plain text eventually.
- Supabase Storage:
  - Use for avatars and post images.
- Supabase Auth:
  - Test real registration/login with the current auth system.
  - Confirm profile rows are auto-created.

Phase 4 priority:
Make the mobile app beautiful, stable, and demoable. Do not overbuild.

## Phase 5: Admin Dashboard

Main goal:
Build the professional React admin panel.

Required features:
- Admin login
- Admin-only route protection
- User management
  - View users
  - Suspend/activate users if needed
  - Approve content creator requests
- Creator approval workflow
  - View pending requests
  - Approve/reject
  - Update `is_content_creator`
- Moderation queue
  - View pending posts/comments
  - Approve/reject/remove content
  - Display AI toxicity score when Phase 6 is connected
- Reports handling
  - View open reports
  - Mark reviewing/resolved/dismissed
  - Add resolution notes

Admin dashboard design direction:
- Professional
- Clean
- Operational
- Not a marketing landing page
- Dense but readable dashboard UI
- Tailwind CSS
- Use icons where helpful

## Phase 6: AI Moderation and Final Polish

Main goal:
Connect Google Perspective API and polish the prototype.

Required features:
- Backend moderation workflow using Google Perspective API.
- Analyze post/comment text toxicity.
- Store:
  - `ai_toxicity_score`
  - `moderation_status`
  - `moderation_reason`
- Hybrid moderation:
  - Low-risk content can be approved automatically.
  - Risky content goes to admin moderation queue.
- Fix demo bugs:
  - Refresh/session crashes
  - Like/dislike sync
  - Save/liked/profile tab consistency
  - Image upload edge cases
- Final polish:
  - Demo seed data if needed
  - Clean testing steps
  - Presentation-ready app flows

Non-features:
- No video calling.
- No marketplace.
- No advanced recommendation engine.
- No NSFW image moderation.
- No overcomplicated social graph.

## 7. Vibe Coding Rules Followed

- Think step by step.
- Explain decisions clearly.
- Ask for confirmation before starting big modules.
- Prioritize clean, maintainable, beautiful code.
- After each major feature, provide testing steps.
- Build demoable features first.
- Prefer polished prototype over broad unfinished scope.
- Keep code scoped to the requested phase.
- Use existing project structure and patterns.
- Do not introduce unnecessary abstractions.
- Avoid role selection during registration.
- Keep parent/child logic table-based.
- Keep admin capabilities separate from mobile users.
- Use Supabase as the main backend.
- Use Express only for privileged operations, AI moderation, and complex workflows.

## 8. Important Decisions and Constraints

- Supabase is the source of truth.
- Flutter is the main user-facing application.
- React admin is only for administrators.
- Express API is not replacing Supabase; it supports privileged and complex operations.
- Service-role key must never be exposed in Flutter or React.
- Anon key is used in Flutter and React.
- Service-role key is used only in Express API.
- All users start as normal users.
- Admin creation uses secure bootstrap endpoint.
- Bootstrap endpoint should only be used once.
- Parent/child roles are determined through `parent_child_links`.
- Content creator status is requested by user and approved by admin.
- Registration must remain simple:
  - Email
  - Password
  - Confirm password
  - Name
- The project should remain presentation-ready and not become too large to finish.

## 9. Useful Commands

Flutter:

```powershell
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

API:

```powershell
cd services/api
npm install
npm run typecheck
npm run build
node dist/server.js
```

Admin:

```powershell
cd apps/admin
npm install
npm run build
npm run dev
```

Supabase SQL run order:

```text
1. supabase/storage.sql
2. supabase/schema.sql
3. supabase/auth.sql
```

## 10. What the Next AI Should Do First

Start Phase 4.

Recommended first steps:
- Inspect existing Flutter files.
- Keep the current auth gate.
- Replace placeholder pages with real feature pages gradually.
- Start with the mobile app shell and Home Feed.
- Then implement Post Creation with Supabase Storage.
- Then Post Detail interactions.
- Then Profile tabs.
- Then Parent-Child supervision flow.
- Run `flutter analyze` and `flutter test` after meaningful changes.

The next AI should not restart from scratch. The project already has working setup, schema, auth foundation, and first admin creation.

## 11. Secret Handling Note

Do not paste service-role keys into public chat or shared handover text. Local `.env` files in the workspace contain the runtime values used during development. The service-role key must stay backend-only.
