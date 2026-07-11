# CyanZone Mobile

Flutter application for CyanZone's educational social, chat, and family-safety experience.

## Implemented Modules

- Authentication and profile management
- Educational waterfall feed, search, post creation/editing, and post details
- Comments, replies, mentions, reactions, saves, reports, and sharing
- Direct/group chat, message requests, text/images, shared-post messages, unread state, group management, and local recent-history caches
- Activity, System, and New Followers pages with in-app badges/read state
- Parent-child repository and safety-center foundations

External device push notifications, Gemini moderation, and the complete parent-child supervision workflow are not implemented yet.

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
