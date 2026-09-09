# CyanZone Mobile

Flutter application for CyanZone's educational social, chat, and family-safety experience.

## Implemented Modules

- Authentication and profile management
- Educational waterfall feed, search, post creation/editing, and post details
- Comments, replies, mentions, reactions, saves, reports, and sharing
- Relationship-gated direct/group chat, text/images, shared-post messages, unread state, group management, and local recent-history caches
- Dormant message-request data and backend foundations retained without active mobile loading or UI
- Group-chat member mentions, admin-only `@all`, tappable profile links, and oldest-first unread mention navigation
- Activity, System, and New Followers pages with in-app badges/read state
- Android push notification permission, per-device FCM registration, foreground/background handling, and safe typed notification destinations
- Parent-child repository and safety-center foundations

Android FCM delivery, Gemini moderation, and the remaining parent-supervision acceptance work are implemented in code. Live Firebase, Supabase webhook, Vercel environment, and device acceptance configuration still require manual setup.

## Run

Create `.env` from `.env.example`, set `SUPABASE_URL` and `SUPABASE_ANON_KEY`, then run:

```powershell
flutter pub get
flutter run
```

## Verify

```powershell
flutter analyze
flutter test
```

For current implementation details, database script order, and next-work handoff, read the repository root `Project_Overview.md` and `docs/setup.md`.
