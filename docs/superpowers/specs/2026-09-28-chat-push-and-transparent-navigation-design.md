# Chat Push Presentation and Transparent Navigation Design

**Date:** 2026-09-28

## Goal

Refine the verified mobile-reliability build without undoing its responsive
bottom-edge behavior:

- Direct-message push notifications show the sender's name as the title and
  preserve the message text as the body.
- Group-message push notifications show the group name as the title and format
  the body as `Sender: message`.
- The full-width area around the floating bottom-navigation pill is transparent,
  while the white pill, its shadow, and its safe positioning remain unchanged.

## Push-notification architecture

The API will enrich a chat notification while loading its authoritative
Supabase row. For chat notifications only, the repository will also load the
actor profile name and the conversation type/title through the notification's
existing foreign keys. The push service will derive the visible title and body
from those fields immediately before sending to Firebase.

For a direct conversation, the visible title is the actor name and the visible
body is the notification's existing message body. For a group conversation,
the visible title is the conversation title and the visible body is the actor
name followed by the message body. Non-chat notifications continue using their
stored title and body without change.

Missing related data must not block delivery. The API will fall back to the
stored notification title when a sender or group name is unavailable, and it
will never emit an empty title or body. This is a push-presentation change only;
it does not require a database migration or alter in-app notification records.

## Navigation architecture

`CyanZoneBottomNavigation` will keep using `BottomSafeSurface` so its height
continues to include the device's bottom safe-area inset. Its outer surface will
be transparent instead of the app background color. Because `MainShell` already
uses `extendBody: true`, page content will remain visible around and behind the
floating navigation while the rounded white pill still protects the controls.

The shared safe-area widget's default remains opaque for bottom controls that
must cover content, including the active chat composer. No other page-level
background or Android system-navigation behavior changes.

## Verification

Automated tests will cover:

- direct chat push title/body formatting;
- group chat push title/body formatting;
- safe fallbacks when related names are missing;
- unchanged formatting for non-chat notifications;
- a transparent navigation outer surface at both tested viewport sizes;
- preservation of the pill styling, physical-bottom anchoring, and safe-area
  height.

After focused tests pass, run Flutter analysis, the full Flutter suite, the full
API suite, and build a new release APK. Physical-device acceptance should check
one direct push, one group push, and navigation appearance on both phones.
