# Future Improvements

This document records useful improvements that are outside the CyanZone MVP scope.

## Background Location Tracking

For the MVP, SOS location updates work only while CyanZone remains open on the child's device. The app sends a new SOS location about every 10 seconds while the SOS is active.

In the future, CyanZone can support location tracking while the app is in the background or the phone is locked. This will require background-location permission, a background service, battery optimisation, and additional privacy controls.

## Cleanup of Unverified Registration Accounts

For the MVP, a user may return from the email verification page and register again with the correct email address. The earlier unverified account will remain in Supabase Auth, but it will not be allowed to sign in or use CyanZone.

In the future, a secure scheduled server task can remove unverified accounts that have been inactive for a chosen period. This cleanup must run on the server because the mobile app must not have administrator access to delete authentication accounts.
