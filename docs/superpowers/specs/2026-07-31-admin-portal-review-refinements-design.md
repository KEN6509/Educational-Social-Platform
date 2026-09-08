# Admin Portal Review Refinements Design

## Goal

Improve administrator decision quality by exposing report patterns, a longer audit history, and complete creator-post context without changing the established Admin Portal layout.

## Scope

This design covers three Admin Portal refinements:

1. Report totals, reason percentages, and a configurable review threshold.
2. Fifteen scrollable recent administrator decisions on Overview.
3. Complete published-post and comment review from Users.

The existing mobile appeal submission and Admin appeal decision flow are already implemented and remain unchanged.

## Reports

### Review threshold

`REPORT_REVIEW_THRESHOLD` remains the single source of truth for deciding when a grouped report case appears in the Admin Portal.

- Local development and functional testing use a threshold of `1` unique reporter.
- Production deployment will set the threshold to `1000` unique reporters before release.
- The threshold must remain environment-configurable so moving between these values does not require a source-code change.
- Both the Overview pending-report count and the Reports queue must use the same configured threshold.

No mock report records and no artificial database rows are required. Testing uses genuine reports submitted from the mobile app.

### Report metrics

Each report case displays:

- Total report count for the content target.
- Unique reporter count, retained as a separate moderation signal.
- Every reported reason, sorted from highest to lowest count.
- The raw count and percentage for each reason.

Reason percentage is calculated as `reason count / total report count * 100`. The UI shows a percentage label and a compact horizontal progress bar. A one-report test case therefore displays one report and its selected reason as `100%`.

## Overview

The Recent Decisions section displays the latest 15 rows from `admin_action_audit`, newest first.

- The API query limit changes from 8 to 15.
- The panel has a fixed maximum height and scrolls internally when the list exceeds the visible area.
- Each row retains the action, reason, administrator identity, and decision time.
- The rest of the Overview layout remains unchanged.

## Users: Published Post Review

### Existing page

The current Users detail page, profile summary, account facts, and Account Decision section remain visually and functionally unchanged.

The creator identity treatment is corrected in the profile header:

- Keep the existing account-status badge, such as **Active**.
- When `isContentCreator` is true, place the same verification mark used by the mobile app immediately to the right of the user's name: a `16px` circular `#2F8FED` blue mark containing a white check, separated from the name by `6px`.
- Give the icon an accessible label of **Verified content creator**.
- Do not render an **Approved** or text-based **Verified** status badge beside the name; `approved` describes content moderation, not the user's identity.

The Published Posts fact must show the user's real total number of approved published posts rather than the size of the five-item recent-post collection.

### Recent Published Content carousel

The existing Recent Published Content section becomes a horizontal carousel:

- It contains only the five latest approved published posts, newest first.
- The carousel shows as many cards as the available width permits; remaining cards stay offscreen within the row.
- Previous and next controls sit vertically centred on the left and right edges of the carousel, not beside the section title.
- Each control moves the row horizontally by one card width and disables at its corresponding boundary.
- Each card includes the first post image when available, title, short excerpt, moderation status, publication date, and comment count.
- Selecting a recent card immediately opens that post in the Post Detail modal.
- A **See all** action remains at the top-right of the section header.

### Post Detail modal

Post Detail uses the approved large A-style modal with a width of `min(90vw, 1440px)` and a height of `90vh`.

The left side is the media viewer:

- Show every post image in stored position order.
- Show the selected image at the largest practical size without distortion.
- Show image thumbnails below the main image when multiple images exist.
- Selecting a thumbnail changes the main image.
- A text-only post uses a neutral no-media state instead of an invented image.

The right side is one continuous scrollable document containing:

1. Author identity.
2. Post title.
3. Full post content without line clamping.
4. All tags.
5. Publishing date.
6. Moderation status.
7. The Comments section directly below the post details.

Comments are read-only and show the public conversation used to assess the creator's community interaction:

- Approved comments only.
- Commenter name and avatar.
- Full comment text.
- Creation date and like count.
- Replies displayed directly beneath and indented from their parent comment.
- Creator identity indicated on the creator's own comments and replies.
- A clear empty state when the post has no comments.

The modal has a visible Close control, closes with Escape, traps keyboard focus while open, and restores focus to the originating post card when closed.

### See All modal

Selecting **See all** opens a modal using the same near-full-page shell as Post Detail.

- Show every approved published post for the selected user, newest first.
- Use a four-column grid on wide desktop screens, reducing columns responsively when required.
- Each card shows the cover image when available, title, publication date, moderation status, and comment count.
- The modal body scrolls when the post collection exceeds its height.
- Do not add search, filtering, or sorting controls.
- Selecting a card changes the same modal shell to Post Detail.
- Returning from Post Detail restores the See All grid and its previous scroll position.

## Data and API Design

The Admin API remains the only data boundary used by the portal.

### User detail projection

Extend the user detail response with:

- `publishedPostCount`: total approved published posts.
- Five recent post summaries containing a cover image URL and comment count in addition to the existing post fields.

### User post collection

Add `GET /admin/users/:userId/posts`.

- Return every approved published post for the user, newest first.
- Include the post fields required by the See All cards.
- Return not-found when the user does not exist.

### Post detail

Add `GET /admin/posts/:postId`.

- Return the full post, ordered image URLs, author details, total comment count, and approved comment thread.
- Read images from `post_images` ordered by `position`.
- Read comments with their profiles and comment-like counts.
- Preserve `parent_comment_id` so the client can render replies beneath their parent.
- Return not-found when the post does not exist.

All new routes use the existing administrator authentication boundary and safe error mapping.

## Loading, Empty, and Error States

- Recent post cards use the existing Users loading state while user details load.
- See All and Post Detail show a contained loading state inside the modal shell.
- A failed modal request shows a retry action without closing the modal or losing the selected user.
- Users with no approved posts retain the existing empty-state message and do not show carousel controls.
- Posts with no images or comments show explicit empty states.
- Report percentages render safely when total report count is zero, although a real case should always contain at least one report.

## Testing Strategy

Implementation follows test-driven development.

- API service tests cover the threshold value of 1, threshold consistency between Overview and Reports, total report counts, reason counts, percentages' source data, 15 audit rows, published-post totals, image ordering, and comment-thread mapping.
- API router tests cover the new user-post and post-detail routes, authentication, validation, and not-found responses.
- Admin component tests cover report counts and percentages, Overview scrolling with 15 decisions, carousel boundaries, side-positioned controls, direct recent-post opening, See All, four-column grid semantics, modal transitions, complete post fields, image selection, comments, replies, empty states, retry states, Escape closing, and focus restoration.
- Browser verification covers all three Admin Portal pages at desktop and narrow widths using real local API data.
- The existing mobile appeal widget and repository tests remain the regression baseline for functional appeal testing.

## Acceptance Criteria

The design is complete when:

1. One genuine mobile report creates a visible Admin report case in the testing configuration.
2. The case shows total reports and every reason's count and percentage.
3. Overview returns and displays the latest 15 decisions inside a scrollable panel.
4. Users still matches its existing layout outside Recent Published Content.
5. Recent Published Content contains only the latest five posts and scrolls horizontally using controls on the row's left and right edges.
6. **See all** opens a near-full-page, four-column, unfiltered post grid.
7. Selecting any recent or See All card opens the same near-full-page Post Detail experience.
8. Post Detail shows every image, the complete post fields, and approved comments directly below the post information.
9. Closing a modal returns the administrator to the same user and interaction position.
10. All API, Admin Portal, and existing mobile appeal tests pass.
