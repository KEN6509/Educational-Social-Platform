# MVP System Notifications Design

## Goal

Deliver an email-like System Notifications experience for two authoritative account events: a user receiving the content creator badge and a user's post becoming rejected. Rejected-post notifications include evidence, post navigation, and a durable appeal workflow that can wait for the future admin moderation interface.

## Scope

This MVP includes only:

- Content creator badge awarded
- Post moderation status transitions to `rejected`
- System notification list cards and detail pages
- Per-notification deletion
- Rejected-post navigation and appeal submission

AI moderation execution, admin appeal review UI, appeal-result notifications, creator benefits, and push delivery are outside this cycle.

## Authoritative Generation

PostgreSQL triggers create notifications from database state transitions rather than from the mobile client:

- `profiles.is_content_creator` changing from `false` to `true` creates one creator-award notification.
- `posts.moderation_status` changing from a non-rejected value to `rejected` creates one post-rejection notification.

This remains reliable when future admin tools, AI moderation workers, or trusted APIs perform the update. Repeated saves of the same state do not create duplicates. Existing profiles and rejected posts are not backfilled.

Generation respects `notification_preferences.in_app_enabled` and `system_enabled`, defaulting to enabled when no preferences row exists.

## Notification Data

The existing `notifications` table remains the notification source. System rows use:

- `type = 'system'`
- `title` for the email-like subject
- `body` for the personalized full message
- `post_id` for rejected-post notifications
- `action_type` equal to `open_rejected_post` or `none`
- `action_payload` containing a stable `template_type`, moderation evidence snapshot, rejection timestamp, scheduled deletion timestamp, and post title when applicable
- `read_at` and `created_at` through the existing lifecycle

Evidence is copied at notification creation so the explanation remains stable if moderation metadata later changes. Available evidence comes from the post's moderation reason and AI score fields; missing evidence displays a neutral fallback rather than inventing a result.

## System Notification List

The System section uses stacked rounded cards inspired by the supplied reference:

- A leading system icon and `System Notification` category label
- A trailing three-dot menu with Delete
- A bold title
- A limited content preview with ellipsis
- The notification date beside the preview
- A `View more` label used as a visual affordance
- The whole card opens its detail page

Opening a card marks that notification read. Deletion requires a confirmation prompt, permanently deletes only that user's notification row, refreshes the list and badges, and never deletes a post or appeal.

## Detail Page

The email-like page contains:

- Back navigation
- A top-right Delete action with confirmation
- Full title and formatted date
- Full body content with clear paragraph spacing
- An inline tappable rejected-post reference when `post_id` exists
- A prominent `Send appeal` action only for an appealable rejected post

The page handles a post that has already been removed by showing a friendly unavailable message. The creator-award page is informational and has no action button.

## Message Templates

### Post Rejected

**Title:** `Your post was not approved`

**Body structure:**

> Hi {username},
>
> Unfortunately, your post “{post title}” was not approved because our moderation system detected content that may not be suitable for CyanZone.
>
> Evidence from moderation:
> {moderation evidence}
>
> Your post will remain in rejected status for seven days and is scheduled for removal on {deletion date}. You may edit the content and publish a revised post, or submit an appeal if you believe the moderation result is inaccurate.
>
> Appeals are sent to the CyanZone administration team for careful review. We will notify you when a future moderation workflow records the outcome.
>
> Thank you for contributing to CyanZone. We hope you continue creating thoughtful and valuable content for the community.

The post title is the tappable portion that opens the owner-visible rejected post.

### Content Creator Badge Awarded

**Title:** `You are now a verified content creator`

**Body structure:**

> Hi {username},
>
> We appreciate the time and effort you have invested in sharing valuable content with the CyanZone community. We are pleased to let you know that you have been awarded the Content Creator badge and are now a verified CyanZone creator.
>
> Our creator programme is still growing. We are planning creator benefits and developing tools such as content analytics, data visualisation, music support, and additional photo-editing options.
>
> CyanZone will continue improving these tools, and we hope you will continue creating content that makes the community more useful, welcoming, and inspiring.
>
> Congratulations, and thank you for being an active part of CyanZone.

## Appeals

Add `public.post_appeals` with:

- `id`
- `post_id`
- `user_id`
- required `reason` between 20 and 500 characters after trimming
- `status` in `pending`, `approved`, or `rejected`
- future-review fields `reviewed_by`, `reviewed_at`, and `admin_note`
- `created_at` and `updated_at`

Only the post author can submit an appeal, and only while the post is still `rejected`. A unique constraint permits at most one appeal per post and user in this MVP. Users can read their own appeals but cannot modify review fields. Admin review policies and UI are deferred.

Tapping `Send appeal` opens a focused form with a multiline explanation field, live character count, 20–500 validation, Cancel, and Submit. A successful submission returns to the detail page and replaces the action with a disabled `Appeal submitted` state. Duplicate or stale submissions return friendly messages.

## Security

- Notification creation runs through security-definer trigger functions with a fixed `public` search path.
- Users can select, mark read, and delete only their own notification rows.
- Appeal insertion validates the authenticated user against both `user_id` and the post author.
- Clients cannot create arbitrary system notifications or modify moderation evidence snapshots.

## Realtime and Badges

System rows continue through the existing Supabase notifications realtime subscription, unread counts, System shortcut badge, main navigation badge, settings preference, and section-level mark-read flow. Deleting a row immediately removes it from subsequent unread calculations.

## Error Handling

- A failed notification deletion leaves the card visible and shows a friendly error.
- A missing rejected post keeps the notification readable but disables post navigation and appeal submission.
- A post that is no longer rejected cannot receive a new appeal.
- A network failure preserves typed appeal text and allows retry.
- Missing moderation evidence displays `No additional moderation evidence was provided.`

## Testing

Tests cover:

- Creator badge and rejection transition detection
- Trigger deduplication and notification preference handling
- Stable payload/evidence and seven-day deletion date
- System card layout, truncation, `View more`, full-card navigation, unread state, menu deletion, and confirmation
- Detail page title, date, full templates, post link, unavailable-post handling, and deletion
- Appeal character validation, author/rejected-state enforcement, duplicate prevention, persistence, retry, and submitted state
- Existing System, Activity, follower, chat badge, realtime, and mark-read behavior

## Manual Supabase Step

The implementation will update repository SQL files but will not apply them remotely. After verification, the user must run the identified updated SQL file in the Supabase SQL Editor. The handoff will include application order and verification queries.
