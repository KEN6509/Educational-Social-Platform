# Admin Portal Flow Simplification Design

Date: 31 July 2026

## Objective

Refine the existing Administration Portal without redesigning its approved structure. Simplify report states and evidence, reuse the complete post-review popup across Users and Reports, keep all administrator decision confirmations, and present AI-Flagged Content as a complete-looking product flow while its isolated temporary data remains replaceable by Gemini later.

## Scope

This change covers:

- Users queue filtering and user-detail actions.
- Recent-post carousel overflow and media presentation.
- Shared Post Detail media navigation.
- Report lifecycle, schema, API, portal tabs, evidence, post viewing, and reason visualization.
- Visible AI-Flagged Content wording and confirmation flow.
- Repository documentation and automated/browser acceptance evidence.

This change does not implement Gemini moderation, apply SQL to a remote Supabase project, delete the account-suspension backend foundation, or redesign unrelated Administration Portal sections.

## Approved approach

Use shared UI and API enforcement rather than UI-only hiding. Administrator profiles are removed at the API query boundary, reported posts open the same Post Detail popup as Users, and the report database domain is genuinely reduced to one unresolved state. Backend account-suspension foundations remain available for future scope, but the Users page no longer exposes them.

## Report data model and migration

### Lifecycle

The report status domain becomes:

```text
pending_review -> resolved
pending_review -> dismissed
```

- `pending_review`: unresolved community reports awaiting an administrator decision.
- `resolved`: the administrator removed the reported content.
- `dismissed`: the administrator retained the reported content.

There is no separate `open` or `reviewing` state. Opening a report case does not mutate its status.

### Migration

Add an idempotent incremental SQL script and update the base schema. The migration must:

1. Convert every existing `open` and `reviewing` report to `pending_review`.
2. Replace `public.report_status` with an enum containing only `pending_review`, `resolved`, and `dismissed`.
3. Set `public.reports.status` to default to `pending_review`.
4. Drop `public.reports.description`.
5. Recreate `reports_one_unresolved_per_reporter_target` so it applies only to `pending_review` reports.
6. Update report-decision functions and unresolved-report predicates to use `pending_review`.
7. Preserve resolved/dismissed history, report reasons, reporter IDs, review timestamps, resolution notes, and audit records.

The migration file is committed to the repository but is not executed against the live Supabase project without a separate explicit approval because dropping a column and replacing an enum are destructive external changes.

### API and mobile consistency

- API `ReportStatus` and validation accept only `pending_review`, `resolved`, and `dismissed`.
- Report list defaults to `pending_review`.
- Repository queries stop selecting or mapping `description`.
- Admin response types remove report descriptions.
- Mobile `createReport` removes the unused optional `description` argument and always creates a reason-only report.
- Overview unresolved report counts use only `pending_review`.

## Users design

### Queue and actions

- The API user-list query excludes `is_admin = true`, so administrator accounts are absent from rows and totals for every client.
- The Users page retains creator assignment/removal, the mandatory decision reason, and its confirmation popup.
- Suspend/Reactivate Account, the self-suspension warning, and the account-status decision action are removed from the Users UI.
- Existing account-suspension API/RPC foundations are retained but are outside the current portal scope.

### Recent posts

- Continue showing only the five newest published posts.
- Cards remain horizontal and fill their media region edge-to-edge with `object-cover`; slight cropping is acceptable and empty white gaps are not.
- Previous/Next controls appear only when the rail's `scrollWidth` exceeds its `clientWidth`.
- Overflow state is recalculated after data changes and container resize using `ResizeObserver` with a safe fallback for tests/environments without it.
- Boundary state updates after scrolling; controls hide entirely when all five cards fit.

### Shared Post Detail media viewer

- Keep the approved near-full-screen split layout, complete metadata, tags, moderation status, approved comments, and replies.
- Remove thumbnail navigation.
- Place Previous and Next circular controls over the left and right edges of the image area; hide both when there is one or no image.
- Place one pagination dot per image at the bottom centre; the active dot is visually distinct and each dot can select its image.
- Display the selected image with `object-contain` inside the available media area so the entire source image remains visible without cropping.
- Maintain keyboard-accessible labels, disabled/boundary behaviour, Escape closing, focus trapping, loading, retry, and empty-image states.

## Reports design

### Queue and tabs

- Tabs are Pending Review, Resolved, and Dismissed.
- Pending Review queries `pending_review`; there is no Reviewing tab.
- Keep search, grouped target rows, two-line target-content previews, total/unique counts, selection behaviour, responsive list/detail navigation, and status labels.

### Report Detail structure

Preserve the current case header, owner details, visibility status, spacing, and decision section. Change only the Reported Content body and the two evidence cards shown in the approved screenshot.

For a post case:

- Keep the Reported Content container.
- Replace its long post body with one text action: `View Post >`.
- Selecting the action lazily loads `/admin/posts/:postId` and opens the shared Users Post Detail popup.
- Closing the popup restores focus and the unchanged Report case underneath.
- Loading, error, and Try Again states are shown inside the shared popup shell.

For a comment case:

- Keep the reported comment text inline inside Reported Content.
- Do not render a View Post action for the comment target.

### Report reason chart

Replace the current two-column Total Reports and Reporter Context cards with one full-width horizontal evidence card:

- Left: total reports and unique reporters.
- Centre: a pie chart using a maintained React chart library rather than handcrafted SVG/CSS artwork.
- Right: a horizontal/wrapping legend showing each reason, count, and percentage.
- Use stable category colours and display exact text values so the chart is not colour-dependent.
- Provide an accessible chart label and retain the reason list as readable text for assistive technology.
- On narrow screens, the same card stacks vertically while preserving the information order.
- Remove Reporter Context and all description/fallback/date rows.

### Decisions

- `Retain content` maps to `dismissed`.
- `Remove content` maps to `resolved`.
- Both actions continue requiring a 10-500 character administrator reason.
- Both actions retain the existing consequence summary and confirmation popup before any request is submitted.
- Conflict, loading, disabled, and failure states remain visible.

## AI-Flagged Content design

- Remove visible labels or explanatory text containing mock, preview, temporary, future, deferred, or not implemented.
- Present the existing queue, detail, statuses, scores, and actions as a normal Administration Portal workflow.
- Every administrator decision retains a confirmation popup with consequence text.
- Keep temporary data isolated in its existing adapter/data files so Gemini integration can replace it later without redesigning the screen.
- Project documentation remains technically truthful that Gemini and the real AI queue are not implemented; only the product UI avoids implementation commentary.

## Component boundaries

- `PostDetailModal` remains the single post evidence viewer used by Users and Reports.
- `ReportReasonChart` is a focused, read-only visualization receiving `reasonCounts` and `totalReports`.
- `RecentPostsCarousel` owns overflow measurement, scroll boundaries, and card presentation.
- `UserDetail` owns only visible creator decision controls; it does not perform filtering.
- `UsersPage` and `ReportsPage` own lazy API loading, errors, retries, modal sources, and focus-return flow.
- The API repository owns administrator exclusion and the simplified report record shape.

## Error handling

- A failed See All or post-detail request shows the existing retry state without losing the underlying selected user/report.
- A post removed between case loading and View Post returns the standard Post Details error with Try Again; the report case remains reviewable.
- A chart with zero report rows displays a clear empty evidence state and never divides by zero.
- Missing or unknown reason labels fall back to the existing stored reason text and a stable fallback colour.
- Decision conflicts refresh the selected case and keep the administrator's visible error feedback.

## Testing and acceptance

### Database/API

- SQL regression tests verify the new enum values, default, dropped description column, updated unique index, and decision predicates.
- API tests reject `open` and `reviewing`, accept/default `pending_review`, omit descriptions, count pending cases, and exclude administrators from Users results and totals.
- Mobile repository tests verify reason-only report insertion.

### Admin components

- Carousel tests cover arrows hidden when content fits, shown only on overflow, scroll boundaries, resizing, and edge-to-edge media classes.
- Post Detail tests cover previous/next controls, dots, complete image presentation, single-image controls, comments, and focus/keyboard behaviour.
- Users tests verify administrators never arrive from the API fixture, suspend actions are absent, creator confirmation remains, and published-post review still works.
- Reports tests verify the three tabs, pending-review query, no description/Reporter Context, post-only View Post, comment inline evidence, chart values, and shared popup loading/error/success flow.
- AI-Flagged tests verify implementation-disclaimer wording is absent and every decision still opens confirmation before state changes.

### Browser acceptance

At desktop and narrow widths, verify:

1. Carousel controls appear only when cards overflow and never cover fully fitting content.
2. Recent images fill their card media region without empty white gaps.
3. Post Detail shows complete images with side controls and bottom dots.
4. Users has no administrator rows and no suspension action.
5. Reports exposes only Pending Review, Resolved, and Dismissed.
6. The preserved Reported Content card opens the shared post popup only for post cases.
7. The merged evidence card is horizontal on desktop, stacked on narrow screens, and shows accurate chart/legend values.
8. Retain, Remove, creator decisions, and AI-flagged decisions all require confirmation.
9. AI-Flagged Content contains no implementation-status disclaimer.

## Documentation updates

Update `Project_Overview.md` to reflect:

- The `pending_review` report lifecycle and removed description field.
- Administrator exclusion and hidden suspension UI.
- Conditional carousel controls and revised post-image navigation.
- Shared Report/User post viewer and reason pie chart.
- AI-Flagged Content UI wording while retaining the truthful Gemini backlog boundary.
