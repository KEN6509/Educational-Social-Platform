# Future Improvements

This document records useful improvements that are outside the CyanZone MVP scope.

## iOS Push Notifications

For the MVP, CyanZone will provide phone push notifications on Android through
Firebase Cloud Messaging. The existing in-app notification lists and badges
will continue to work independently of phone push delivery.

In the future, CyanZone can add iPhone and iPad push delivery through Apple Push
Notification service (APNs). This will require an Apple Developer account, iOS
Firebase configuration, APNs credentials, permission and lifecycle handling,
and testing on a physical Apple device.

## Background Location Tracking

For the MVP, SOS location updates work only while CyanZone remains open on the child's device. The app sends a new SOS location about every 10 seconds while the SOS is active.

In the future, CyanZone can support location tracking while the app is in the background or the phone is locked. This will require background-location permission, a background service, battery optimisation, and additional privacy controls.

## Cleanup of Unverified Registration Accounts

For the MVP, a user may return from the email verification page and register again with the correct email address. The earlier unverified account will remain in Supabase Auth, but it will not be allowed to sign in or use CyanZone.

In the future, a secure scheduled server task can remove unverified accounts that have been inactive for a chosen period. This cleanup must run on the server because the mobile app must not have administrator access to delete authentication accounts.

## Private Chat Media Storage

For the MVP, post images and chat images share the public `images` bucket. Write and delete operations are restricted to the authenticated user's own folder, but anyone who knows a public object URL can read that object.

In the future, chat images can move to a private bucket. CyanZone can then issue short-lived signed URLs only to current conversation members and add a controlled migration and cleanup process for existing chat media.

## Server-Side Moderation Queue Pagination

For the MVP, the Administration Portal loads a bounded moderation-case set and applies search and page slicing in the API. This is suitable for the small UAT data set.

In the future, moderation search, filtering, and cursor pagination can run directly in PostgreSQL. This will reduce API memory use and keep queue loading fast when the number of cases becomes large.
