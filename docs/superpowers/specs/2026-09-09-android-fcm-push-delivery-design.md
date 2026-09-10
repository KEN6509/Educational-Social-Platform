# Android FCM Push Delivery Design

Date: 2026-09-09
Status: Approved for implementation planning

## Context

CyanZone already creates durable in-app notification rows in Supabase and
refreshes badges and lists through Realtime while the app is open. It does not
yet notify an Android device while the app is in the background or terminated.
The Flutter app has no Firebase configuration, and the Vercel API has no push
delivery routes or Firebase Admin credentials.

The profile grid also keeps a deleted post visible until the user refreshes the
page. The post detail page correctly returns a deletion result, but the profile
grid ignores it. This small consistency fix will be completed before the FCM
work and released with the same feature branch.

## Goals

- Remove a successfully deleted post from the visible profile grid immediately.
- Deliver supported CyanZone notification events to Android devices through
  Firebase Cloud Messaging.
- Preserve the existing Supabase notification rows as the source of truth.
- Keep Firebase server credentials and the Supabase service-role key in the
  Vercel API only.
- Register multiple Android devices per user and handle token refresh, sign-out,
  account changes, invalid tokens, and app reinstalls safely.
- Keep in-app and phone-push master preferences independent while sharing the
  existing Chat, Activity, System, and New Followers category preferences.
- Support safe notification navigation from foreground, background, terminated,
  and signed-out app states.
- Provide bounded retry, deduplication, and delivery records suitable for MVP
  troubleshooting.

## Non-goals

- iOS push delivery through Apple Push Notification service (APNs).
- Web push notifications.
- Rich notification images, inline replies, notification grouping, or custom
  sounds.
- A continuously running queue worker or production-scale message broker.
- Replacing Supabase notification lists, badges, read state, or Realtime.
- Retrospective push delivery for notification rows created before this feature
  is installed.

## Considered Approaches

### 1. Supabase database events to the Vercel API and FCM

This is the selected approach. Supabase Database Webhooks send new notification
rows to a protected Vercel endpoint. The API reloads the authoritative row,
recipient preferences, and active device tokens with the service-role client,
then sends through Firebase Admin.

This reuses CyanZone's deployed backend, keeps privileged logic in one place,
and covers events created by mobile actions, SQL triggers, supervision
functions, Gemini moderation decisions, and Administration Portal actions.

### 2. Supabase Edge Function delivery

An Edge Function could receive the database webhook and call FCM. It would
shorten the network path but introduce a second backend runtime, duplicate
secret management, and split notification rules between Supabase and Vercel.

### 3. Sender-side mobile delivery requests

The device performing an action could call the API after the database write.
This is simpler but misses SQL-generated and administrator-generated events
when the sender loses connectivity, closes the app, or never receives
confirmation of the database write. It is not selected.

## Architecture

The event flow is:

1. Existing application logic inserts a row into `notifications` or
   `supervision_notifications`.
2. A Supabase Database Webhook sends the inserted row to
   `POST /push/events` on the Vercel API.
3. The API authenticates the webhook with `PUSH_WEBHOOK_SECRET` and validates
   the table, event type, row ID, and recipient ID.
4. The API reloads the row from Supabase instead of trusting mutable webhook
   content.
5. It maps the event to a stable push category and safe deep-link payload.
6. It checks `push_enabled` and the existing category preference for the
   recipient.
7. It claims a unique delivery record and loads that user's active Android
   device tokens.
8. Firebase Admin sends one notification-plus-data message per active token.
9. The API records success or failure per delivery attempt and revokes tokens
   that Firebase reports as invalid or unregistered.

The webhook handler is stateless and safe to run as a Vercel Function. A unique
source-table and source-row constraint prevents duplicate webhook calls from
sending the same logical notification twice.

## Database Design

### Device registrations

Add `public.push_device_tokens` with:

- `id` UUID primary key;
- `user_id` referencing `profiles` with cascade deletion;
- `token` containing the FCM registration token;
- `platform` restricted to `android` for this MVP;
- `device_id` containing an app-generated installation identifier;
- `is_active` for revocation without losing troubleshooting history;
- `last_seen_at`, `created_at`, and `updated_at` timestamps.

The token is globally unique because one FCM registration token must belong to
only one active CyanZone account. The user/device pair is also unique so token
refresh replaces the previous value instead of adding duplicates.

Clients do not write this table directly. Row Level Security allows a user to
read only their own active registrations for support visibility, while all
registration, refresh, transfer, and revocation writes pass through the
authenticated API.

### Preferences

Add `push_enabled boolean not null default false` to
`notification_preferences`. Existing category fields retain their meanings:

- `chat_enabled` controls direct and group message pushes;
- `activity_enabled` controls likes, saves, comments, replies, mentions, and
  comment likes;
- `system_enabled` controls moderation, appeals, creator decisions, and all
  parent-supervision notifications;
- `followers_enabled` controls new-follower pushes.

`in_app_enabled` continues to control only in-app lists and badges.
`push_enabled` controls only phone push. Turning either master preference off
does not alter the other master preference or erase category choices.

To preserve that independence, add `in_app_visible boolean not null default
true` to both notification source tables. Existing producer functions may
create a row when the matching category is enabled and either master channel
is enabled. A shared `BEFORE INSERT` preference trigger then:

- discards the row when its category is disabled or both master channels are
  disabled;
- stores `in_app_visible = in_app_enabled` for accepted rows; and
- leaves the service-role API able to load push-only rows while normal member
  reads, Realtime lists, and badge queries expose only `in_app_visible = true`
  rows.

Existing rows are backfilled as visible. This also prevents a push-only row
from unexpectedly appearing in the in-app history if the user enables in-app
notifications later.

### Delivery records

Add `public.push_deliveries` with:

- `id` UUID primary key;
- `source_table` restricted to `notifications` or
  `supervision_notifications`;
- `source_id`, `user_id`, and mapped category;
- `status` restricted to `processing`, `delivered`, `partial`, `skipped`, or
  `failed`;
- `attempt_count`, `success_count`, and `failure_count`;
- a concise safe `last_error_code` without secrets or complete tokens;
- `started_at`, `completed_at`, `created_at`, and `updated_at`.

A unique constraint on `(source_table, source_id)` provides logical
deduplication. These records are backend-only and are not exposed to normal
mobile clients.

## API Design

### Member device endpoints

- `PUT /push/devices` authenticates a normal Supabase member and upserts the
  submitted Android installation ID and FCM token.
- `DELETE /push/devices/:deviceId` authenticates the member and deactivates only
  that member's matching installation.
- `GET /push/events/:sourceTable/:sourceId` authenticates the member and returns
  the safe typed destination only when the source row belongs to that member.
  This supports push-tap navigation for rows intentionally hidden from in-app
  lists when the in-app master switch is off.

The registration body is schema validated. Tokens and device identifiers are
bounded non-empty strings. A token already assigned to another account is
transferred atomically to the currently authenticated user, preventing push
content from reaching a previous account on a shared phone.

### Webhook endpoint

`POST /push/events` requires an exact `x-cyanzone-webhook-secret` header match.
It accepts only Supabase `INSERT` webhook payloads for the two approved public
tables. The endpoint rejects missing, malformed, untrusted, or mismatched rows
without sending.

The service layer owns preference mapping, delivery claiming, retry policy,
payload construction, and invalid-token handling. The repository owns
authoritative Supabase reads and writes. A Firebase gateway adapts CyanZone's
push message model to Firebase Admin, keeping Firebase types out of the router
and service.

### Retry and result rules

- Retryable Firebase transport or service-unavailable failures receive one
  short bounded retry during the same Vercel request.
- Permanent invalid-registration errors deactivate the affected token and are
  not retried.
- A partial device result records both success and failure counts.
- No active token, push disabled, or category disabled records `skipped` rather
  than an operational failure.
- A repeated webhook for a completed or skipped source row returns the stored
  result without resending.
- A processing claim has a short expiry so an interrupted Vercel invocation can
  be reclaimed by a repeated webhook rather than remaining locked forever.

## Push Event Mapping

Rows from `notifications` map as follows:

- `chat_message` to Chat and the conversation route;
- `like`, `favorite`, `comment`, `comment_reply`, `mention`, and `comment_like`
  to Activity and the referenced post/comment route;
- `new_follower` to New Followers and the actor profile route;
- `system` to System and the specific System notification detail route.

Rows from `supervision_notifications` use the System category and their
existing typed identifiers:

- link events open Family Links;
- check-in events open the fixed Check-In detail;
- SOS events open the live or resolved SOS detail;
- screen-time events open the relevant supervision dashboard.

Every FCM data value is a string and includes a payload version, source table,
source ID, route type, and only the minimum identifiers needed to resolve the
destination. The app reloads authorized content from Supabase after navigation;
the push payload is never treated as proof of access.

## Android Mobile Design

Add Firebase Core, Firebase Messaging, and local-notification support. Firebase
initializes before the app starts using generated, non-secret Android project
configuration. The Firebase service-account credential is never placed in the
Flutter project.

### Permission flow

After the first successful sign-in on Android, CyanZone displays its own short
explanation with `Enable notifications` and `Not now` actions. Enable opens the
Android notification permission prompt. Not now leaves `push_enabled` false and
does not block any feature. Notification Settings can initiate the same flow
later.

When permission is granted, the app sets `push_enabled` true, obtains an FCM
token, creates or restores the installation ID, and registers both with the
API. Denial preserves all in-app notifications and leaves phone push disabled.

### Token lifecycle

The app registers the current token after an authenticated session becomes
available, listens for Firebase token refresh, and sends replacement tokens to
the API. On explicit sign-out it asks the API to revoke the current device
registration before clearing the Supabase session. If remote revocation fails,
the token remains protected by server-side account and preference checks, and
the next authenticated registration transfers the installation safely.

### Message handling and navigation

- Foreground: display a small local notification and allow tapping it.
- Background: Android displays the notification supplied by FCM; tapping routes
  through `FirebaseMessaging.onMessageOpenedApp`.
- Terminated: the app reads `getInitialMessage` after startup.
- Signed out: store one pending destination locally, show authentication, and
  consume it only after a valid session exists.

A central `PushNotificationCoordinator` converts versioned payloads into typed
destinations. Existing notification and supervision routers remain responsible
for opening their actual pages. Unknown versions, missing identifiers,
unauthorized targets, and deleted content show a friendly unavailable message
instead of guessing a route.

## Notification Settings

Replace the current explanatory text saying phone push is unavailable with a
`Phone push notifications` master switch. Its state combines the stored
`push_enabled` preference with Android permission capability:

- switching on begins the explanation and permission flow when required;
- switching off saves `push_enabled = false` and deactivates the current device
  registration;
- if Android permission is permanently denied, the page explains that the user
  must enable notifications from system settings;
- category switches remain enabled when either in-app or phone push is enabled.

## Immediate Deleted-Post Removal

The shared post interaction update model will represent deletion explicitly.
When `PostDetailPage` returns `deleted: true`, `FeedCard` publishes that result
without trying to retain its old post. Profile, home, saved, and liked lists
remove the matching post immediately. The profile's memory and disk caches are
updated at the same time, preventing the removed card from flashing back before
the next network refresh. The visible own-profile post count decreases once and
is reconciled with the server on the next normal profile refresh.

## Security and Privacy

- Firebase Admin credentials, the Supabase service-role key, and
  `PUSH_WEBHOOK_SECRET` exist only in Vercel environment variables.
- Device routes require a valid Supabase access token and active normal member.
- The webhook route uses a separate high-entropy secret and reloads every event
  from Supabase before delivery.
- Tokens are never logged or returned from delivery endpoints.
- Push bodies use the existing user-facing notification title and body but do
  not include moderation evidence, private message content beyond the existing
  short notification body, precise location coordinates, or other sensitive
  record details.
- Deep links always re-check Supabase authorization and current record state.
- Disabled preferences are enforced by the API, not trusted to the client.

## Failure Handling

- Firebase unavailable: retry once, record a safe failure, and leave the in-app
  notification available.
- Webhook unavailable: the database insert remains successful because Supabase
  webhooks are asynchronous; its request history provides deployment evidence.
- Permission denied: do not register a token; in-app notifications continue.
- Token registration unavailable: keep the app usable and retry registration on
  the next authenticated startup or token refresh.
- Invalid token: deactivate only that token and continue sending to the user's
  other devices.
- Notification target removed or inaccessible: open the relevant notification
  area and show the existing friendly unavailable state.
- Duplicate webhook: return the existing delivery record and do not send twice.

## Testing

Automated verification covers:

- deleted-post results removing the card from visible lists and both caches;
- preference independence and category mapping;
- member authentication and ownership for device registration and revocation;
- token transfer, refresh, uniqueness, and invalid-token deactivation;
- webhook secret validation, supported-table validation, and authoritative row
  reload;
- event-to-category and event-to-deep-link mapping for both notification tables;
- delivery idempotency, processing-claim expiry, skipped outcomes, bounded
  retry, partial success, and safe error recording;
- Firebase gateway payload construction without credential or token logging;
- Android permission decisions, token lifecycle, foreground handling,
  background/terminated taps, signed-out deferred navigation, and unknown
  payload fallback;
- existing in-app Realtime, badge, read-state, moderation, chat, and supervision
  behavior remaining unchanged;
- API tests, type-check, and build plus scoped Flutter tests and analysis.

Manual verification uses at least two Android accounts and one physical Android
device to test foreground, background, terminated, denied-permission,
category-disabled, sign-out/account-switch, chat, moderation, and SOS delivery.

## Deployment and Manual Configuration

Implementation will require the user to:

1. Create or select a Firebase project and register the Android application as
   `com.cyanzone.mobile`. The implementation will replace the current
   placeholder `com.example.cyanzone_mobile` application ID and namespace with
   this value before Firebase configuration is added.
2. Download Firebase's Android configuration file to the exact mobile app path
   provided in the implementation handoff.
3. Create a Firebase service account credential and store its required fields
   only in Vercel environment variables.
4. Add `PUSH_WEBHOOK_SECRET` and Firebase environment values to the Vercel API,
   then redeploy it.
5. Run the complete updated push SQL in Supabase SQL Editor.
6. Create two Insert Database Webhooks, one for `notifications` and one for
   `supervision_notifications`, pointing to the deployed `/push/events`
   endpoint and carrying the private webhook header.
7. Build and install a fresh Android application, grant notification permission,
   and execute the manual delivery matrix.

Exact dashboard values and verification checks will be supplied one step at a
time after implementation. Secrets and downloaded credentials will not be
committed.
