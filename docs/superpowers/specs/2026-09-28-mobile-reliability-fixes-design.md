# Mobile Reliability Fixes Design

**Date:** 2026-09-28
**Status:** Approved for implementation planning

## Context

Device testing exposed five issues that should be resolved together before producing the next Android test build:

1. Profile names are not validated consistently during registration and profile editing.
2. In-app notifications arrive, but Android push notifications do not appear when the app is outside the foreground.
3. Bottom-aligned UI leaves a visible strip or oversized gap on some devices and aspect ratios.
4. Floating snackbars have a heavy shadow and sit too far above the bottom navigation.
5. The System notification unread badge can remain visible after the section has been read.

The work will use focused shared fixes rather than a broad UI or state-management rewrite.

## Goals

- Enforce one name rule everywhere: a trimmed, non-empty value of 1–24 characters.
- Restore background and terminated-state push delivery without committing Firebase secrets.
- Make bottom-aligned UI reach the physical screen edge on all supported Android layouts while keeping controls clear of system navigation and gestures.
- Make shared snackbars visually lighter and closer to the bottom navigation.
- Clear notification badges immediately after a successful read operation while retaining server reconciliation.

## Non-goals

- Redesigning registration, profiles, navigation, chat, or notifications.
- Replacing the existing state-management architecture.
- Changing notification preferences or bypassing Android notification permissions.
- Committing Firebase service-account credentials to the repository.

## 1. Shared profile-name policy

Introduce a reusable profile-name policy used by both registration and Edit Profile.

- Trim leading and trailing whitespace before validation and persistence.
- Reject an empty or whitespace-only value.
- Accept 1 through 24 characters after trimming.
- Prevent input beyond 24 characters where practical, while retaining validation as the source of truth.
- Display helper text such as `1–24 characters` before submission.
- Display a clear inline error below the field when the value is invalid.
- Block registration or profile saving until the value is valid.

The database will receive a matching constraint for `profiles.name`. The migration must first check existing rows and avoid breaking deployment when historical data is invalid; any invalid rows must be identified and corrected before the constraint is fully validated.

## 2. Firebase push-delivery configuration

The application-side setup is healthy enough to register devices: two active device records exist, push preferences remain enabled, and notification webhooks are installed. Delivery records fail with `messaging/mismatched-credential`.

The Android application uses Firebase project `fyp040605`, but the Firebase Admin credentials configured for the deployed API do not match that project. The deployment fix is to replace these Vercel environment variables with a service account from `fyp040605`, then redeploy the API:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

No credential value will be written to source control, logs, documentation, screenshots, or test fixtures. Changing deployed secrets requires explicit confirmation at the time of the external change.

Verification will create fresh Chat, System, and Follower events. Each event must produce a delivered push record with a positive success count and show an Android notification while the recipient app is in the background or normally terminated. A force-stopped app is excluded because Android blocks delivery until the user reopens it.

## 3. Responsive bottom surfaces

The problem is not only the color of Android's navigation area. On affected devices, bottom controls are positioned above a separately visible safe-area gap, so taller screens or different navigation modes can expose an oversized gray or transparent strip. This affects all routes, including pages without the main navigation and the chat composer.

The responsive rule is:

- Every bottom surface extends to the physical bottom edge of the window.
- The device bottom inset is applied **inside** that surface as padding for interactive controls, never as an external transparent gap.
- The main bottom-navigation region reaches the screen edge; its floating navigation control keeps consistent visual spacing within that region.
- The chat composer surface reaches the screen edge; its text input and send controls remain above gesture or navigation-key insets through internal padding.
- Other reusable bottom action areas, sheets, and page-specific bottom controls follow the same ownership rule.
- Layout is derived from `MediaQuery` insets and constraints, not fixed dimensions tailored to a particular phone.

The app-level Android system-bar style will also be reviewed so an avoidable contrast scrim or divider does not reintroduce a line. That system setting complements the responsive layout; it is not the primary fix.

## 4. Shared snackbar presentation

Update the reusable feedback snackbar rather than individual call sites:

- Reduce elevation from 10 to 4.
- Reduce the bottom margin from 18 px to 8 px.
- Retain the existing radius, border, icon, actions, colors, and accessibility behavior.

This produces a softer shadow and places feedback closer to the navigation without overlapping it.

## 5. Immediate unread-badge reconciliation

When the user leaves a notification section, the existing read RPC remains the authoritative persistence step.

- Await the read RPC before treating the section as read.
- On success, return the read section to the Messages page.
- Immediately set the corresponding locally cached unread count to zero.
- Recompute both the section indicator and the main bottom-navigation badge from the updated local counts.
- Start a background refresh to reconcile with the server without delaying the visible badge update.
- If the RPC fails, preserve the unread state and provide a meaningful retry or error path instead of silently clearing the badge.

This avoids the current dependency on a full refetch and prevents stale refresh races from keeping the red dot visible for several navigation cycles.

## Testing and verification

### Automated tests

- Name policy: whitespace-only, one-character, 24-character, and 25-character cases.
- Registration and Edit Profile: helper text, inline errors, and blocked invalid submission.
- Database migration: valid rows pass and invalid rows are detected before validation.
- Bottom surfaces: multiple viewport heights/aspect ratios with zero and non-zero bottom insets, both with and without the shared navigation.
- Chat composer: controls remain usable while its surface reaches the physical bottom.
- Snackbar: shared elevation and margin values are applied.
- Notifications: successful System reads clear section and shell badges immediately; failed reads preserve them; later refreshes do not restore stale counts.

### Device checks

- Test Android navigation keys and full-screen gestures.
- Test at least the original phone and the taller phone that exposed the gray strip.
- Inspect Home, Profile, Messages, notification sections, and an active chat.
- Confirm snackbars on both a main-navigation page and a nested page.
- Confirm foreground in-app delivery and background/terminated push delivery between two physical accounts.

## Rollout and safety

1. Implement and test repository changes without including the existing unrelated `docs/Future_Improvements.md` edit.
2. Apply the database name constraint only after checking existing data.
3. Update Firebase Admin secrets in Vercel only with explicit authorization, then redeploy.
4. Run physical-device regression checks before sharing the APK.
5. Keep rollback limited: repository changes can be reverted independently from the Vercel credential update.
