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
- Parent/child linking, screen-time reminders, Safety Check-In, foreground SOS
  tracking, safety records, supervision notifications, two-party unlinking, and
  time-window-authorized historical records

The current Supabase migrations, Gemini/API deployment, Firebase Android
configuration, Vercel environment, and notification webhooks are configured.
Android FCM physical-device UAT and the broader final acceptance record remain.
iOS/APNs delivery is intentionally deferred.

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

For current implementation details, database script order, and the documentation
handover, read the repository root
[`Project_Overview.md`](../../Project_Overview.md) and
[`docs/setup.md`](../../docs/setup.md).
