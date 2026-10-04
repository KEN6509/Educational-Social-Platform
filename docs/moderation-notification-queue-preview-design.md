# Moderation notifications, live queue, and draft image preview

## Scope and decisions

This design addresses three independent defects in CyanZone. A new comment is initially pending moderation; only an approved comment is published and may generate Activity notifications. The post author and any distinct relevant reply or mention recipient should be notified after approval. The commenter continues to receive the separate author-facing moderation result. Rejected comments must not generate Activity notifications to other users.

The AI-Flagged Content queue must show newly submitted cases without requiring an administrator to leave and reopen the page. A selected image in the Create Post grid must be previewable without changing the draft. No new SQL migration file, manual deployment, or `docs/superpowers` directory is part of this work.

## Notification flow

The existing `public.notify_post_comment()` function in `supabase/chat.sql` currently runs after comment insertion, before the moderation decision. Keep its recipient selection and notification payloads, but run it after an update of `moderation_status` and only when that status transitions from `pending` to `approved`. Post authors receive the comment/reply Activity event, parent-comment authors receive a reply event, and tagged users receive a mention event. A user who fills more than one recipient role receives only one Activity event for that comment. Self-notifications remain suppressed. The existing `notify_comment_approved()` author-facing System notification stays separate.

When one user fills multiple roles, post-author notification takes precedence over reply, and reply takes precedence over mention. The trigger must not emit an Activity event for `pending` or `rejected` comments, nor repeat one on an unrelated update to an already approved comment. The change is made in the existing `chat.sql`; applying the updated function and trigger to the live Supabase database remains a separate post-merge step.

## Administration queue refresh

`AiFlaggedContentPage` already fetches cases through the authenticated admin API and preserves a previously loaded queue on refresh failure. Keep that API boundary. While the page is mounted and the document is visible, refresh the active queue on a short bounded interval (15 seconds) and immediately when the tab returns to the foreground. Stop the timer on unmount or tab change. Do not poll while a decision is being submitted or its confirmation dialog is open; the existing post-decision reload remains in place.

Background refresh must not replace visible rows or the empty state with a loading flash. Preserve the selected case by ID if it still exists, and select the first case only when the prior selection disappears. Older responses must not overwrite newer tab or refresh results. If a refresh fails, retain the last successful rows and show the existing non-blocking error; a subsequent successful refresh clears the error. The API already sorts cases newest first, so a newly added pending case appears on the next refresh.

## Create Post image preview

Tapping any selected thumbnail in the nine-image grid opens a black full-screen preview at that image. The user can swipe through all selected images, pinch to zoom, and close to return to the unchanged draft. The existing remove control remains independent so that tapping its close icon never opens the preview. The preview supports both newly picked image bytes and existing network images shown while editing a post.

Reuse the post-detail preview's existing zoom/pan behavior by extracting the reusable image-viewing portion into a shared widget used by both post detail and Create Post. Preserve post detail's current Hero transition and download capability. Draft preview has no download or delete action; it only inspects the images already selected.

## Verification

- SQL regression tests assert that Activity creation is gated on the `pending` to `approved` transition and that the insert-time trigger is removed. Inspect recipient deduplication and self-notification behavior.
- Admin component tests use controlled timers and API responses to verify automatic arrival of a new case, focus refresh, stale-response protection, preserved rows on error, and timer cleanup.
- Flutter widget tests tap a picked and an existing thumbnail, verify the correct initial image and paging, and confirm that closing does not remove an image. Existing post-detail preview tests guard its download and navigation behavior.
- Run the affected suites and then the full relevant mobile, admin, and API tests. Live Supabase notification behavior requires a post-merge database application and an end-to-end check with approved and rejected test comments.
