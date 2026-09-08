# Admin Portal Interaction Corrections Design

Date: 1 August 2026

## Objective

Correct the Administration Portal interactions that currently appear unresponsive, complete the media presentation on Users, and keep the approved confirmation flow for every administrator decision. Positive, non-punitive actions must no longer be blocked by a decision-reason field that is intended only for actions requiring an explanation.

This specification supersedes the decision-reason rules in the 31 July 2026 Admin Portal flow specification where they conflict with the matrix below. The existing page structure, report evidence layout, shared Post Detail popup, and isolated AI-Flagged Content data adapter remain unchanged.

## Root causes confirmed

- Users, Reports, and AI-Flagged Content share `DecisionPanel`, which currently disables both actions until a 10-500 character reason is present. This makes valid positive actions look broken.
- Recent-post cards are native buttons without a column layout. Browser layout centres their contents vertically and leaves a white strip above the image.
- The recent-post hover translation moves a card above the rail's clipping boundary.
- Post Detail uses an image whose computed height can exceed the media stage even with `object-contain`; the stage then clips the oversized element.
- AI queue-tab totals are visually inconsistent with the other Administration Portal queues.

## Approved decision matrix

| Page | Action | Manual reason | User notification |
| --- | --- | --- | --- |
| Users | Assign creator | Not required | Automatic creator-congratulations notification |
| Users | Remove creator | Required, 10-500 characters | Creator-removal notification |
| Reports | Retain content | Not required | None |
| Reports | Remove content | Required, 10-500 characters | Content-removal notification |
| AI-Flagged Content | Approve content | Not required | Automatic successful-publication notification for an uncertain post |
| AI-Flagged Content | Reject content | Required, 10-500 characters | Content-rejection notification |
| Appeals | Approve appeal | Required, 10-500 characters | Appeal-approved notification |
| Appeals | Reject appeal | Required, 10-500 characters | Appeal-rejected notification |

Creator Requests are not part of this correction and retain their current reason requirements.

## Decision interaction design

### Shared behaviour

- Every decision continues to open a confirmation popup before submission.
- A reason-free positive action can be selected while the reason field is empty.
- An action requiring a reason cannot submit until the trimmed reason contains 10-500 characters.
- Selecting a reason-required action with invalid input displays an inline validation message and moves focus to the reason input. The action must not appear to do nothing.
- During submission, decision buttons and confirmation controls are disabled to prevent duplicate requests.
- Success refreshes or updates the selected record, shows the existing success feedback, and closes the confirmation popup.
- Failure keeps the administrator on the current record and displays the existing actionable error feedback.

### Users

- `Assign creator` opens its confirmation popup without a manually entered reason.
- `Remove creator` keeps the decision-reason field and requires 10-500 characters.
- The existing database trigger that reacts to `profiles.is_content_creator` changing to true remains the source of the congratulatory system notification.
- Removal retains its existing administrator-decision notification.

### Reports

- `Retain content` opens its confirmation popup without a manually entered reason and does not notify the author.
- `Remove content` requires a 10-500 character reason and retains the content-removal notification.
- Both actions retain the existing consequence summary in their confirmation popup.

### AI-Flagged Content

- `Approve content` opens its confirmation popup without a manually entered reason.
- `Reject content` requires a 10-500 character reason.
- Remove numeric badges from all AI queue tabs; retain the existing tab labels and active-state styling.
- The current queue remains backed by its isolated temporary UI adapter until Gemini integration. The portal must not fabricate a real recipient notification from a temporary record.
- Add the database notification foundation for the real workflow: when an uncertain post changes from `pending` to `approved`, its author receives a system notification that the content was published successfully. The existing rejected-content notification remains in place.

### Appeals

- Both decisions continue requiring a 10-500 character reason.
- Both confirmation popups and both existing notification paths remain unchanged.

## Validation and audit design

`admin_action_audit.reason` remains non-null and retains its 10-500 character constraint. The database and API do not weaken the audit trail for actions that have no manual reason.

For each approved reason-free action, the service supplies a stable internal audit explanation when the request reason is blank:

- Assign creator: `Creator status assigned by an administrator.`
- Retain reported content: `Reported content retained by an administrator.`
- Approve uncertain content: the real moderation workflow records an equivalent system-generated publication audit explanation when integrated.

The API schemas conditionally require a manual reason based on the requested action:

- `isCreator: true` accepts an omitted or blank reason; `isCreator: false` requires 10-500 characters.
- Report decision `retain` accepts an omitted or blank reason; `remove` requires 10-500 characters.
- AI temporary decisions enforce the same approved/rejected distinction in the Admin client. Any future real API endpoint must enforce it again server-side.
- Appeal approve and reject continue requiring 10-500 characters.

Client-side validation improves feedback, but API/database validation remains authoritative for real persisted actions.

## Users media corrections

### Recent Published Content

- Preserve the horizontal five-recent-post carousel, side controls, conditional overflow behaviour, `See all`, and existing card information.
- Make each card button an explicit vertical flex container so its media starts at the top rather than being vertically centred by native button layout.
- Give the media wrapper an explicit height and `overflow: hidden`; the image fills it with `width: 100%`, `height: 100%`, and `object-cover`.
- Make the card body fill the remaining card width and height so no unintended white strip appears around the media.
- Keep the slight upward hover movement.
- Add enough top clearance inside the carousel viewport for the lifted card and its border/shadow. If browser geometry still shows clipping after the clearance is applied, remove only the vertical translation while retaining the hover border/shadow feedback.

### Post Detail image stage

- Preserve the approved near-full-page Post Detail popup, split layout, image controls, bottom dots, metadata, full content, tags, dates, moderation status, comments, and replies.
- Match the mobile app's `BoxFit.contain` behaviour: the selected source image must be fully visible without cropping or distortion.
- The image is constrained to the media stage itself, using an absolute inset/fill layout or an equivalent layout whose computed width and height cannot exceed the stage.
- Centre the image on a neutral dark media background so portrait, landscape, and square images remain visually distinct.
- Keep Previous and Next controls at the sides and pagination dots at the bottom; hide multi-image navigation when the post has only one image.
- Preserve a clear no-media state for text-only posts.

## Component and data boundaries

- `DecisionPanel` owns conditional reason requirements, visible validation, and opening the shared confirmation popup.
- Each page supplies which of its actions require a manual reason and keeps its current decision handler.
- API schemas express action-dependent reason validation; services generate internal audit reasons for permitted reason-free persisted actions.
- Existing SQL RPC audit and notification behaviour remains authoritative.
- `RecentPostsCarousel` owns card layout, media fill, overflow measurement, and hover clearance.
- `PostDetailModal` remains the single post evidence viewer used by Users and Reports.
- AI temporary queue mutation remains local to its isolated adapter; real post-publication notification is implemented at the database transition boundary.

## Error and edge cases

- Whitespace-only text counts as no manual reason.
- A 1-9 character reason for a punitive or appeal decision displays a minimum-length message before confirmation.
- A reason longer than 500 characters displays a maximum-length message before confirmation.
- Closing a confirmation popup submits nothing and preserves the entered reason.
- An API conflict or stale-record response refreshes the affected item through the existing page behaviour.
- Failed notifications must follow existing transaction behaviour and must not create duplicate administrator decisions.
- Images that fail to load show the current media fallback without collapsing the modal stage or controls.
- Long portrait images, the reported failing case, and landscape images must all fit completely in Post Detail.

## Test-driven implementation

Write failing regression tests before production changes.

### Admin component tests

- `DecisionPanel`: a reason-optional primary action opens confirmation with empty input; a reason-required negative action shows inline validation and does not submit; valid input opens confirmation; confirmation submits once.
- Users: Assign creator works without a reason; Remove creator requires a reason; confirmation is present for both.
- Reports: Retain works without a reason; Remove requires a reason; confirmation is present for both.
- AI-Flagged Content: Approve works without a reason; Reject requires a reason; confirmation is present for both; queue tabs have no numeric badges.
- Appeals: both actions still require a reason and confirmation.
- Recent posts: explicit column/card/media-fill classes and hover clearance are present; conditional side controls still behave correctly.
- Post Detail: the selected image is bounded by the media stage and uses contain sizing; arrows, dots, and single-image behaviour remain correct.

### API and SQL tests

- Conditional creator and report schemas accept only the approved reason-free actions.
- Services replace blank permitted reasons with the exact internal audit explanations before RPC calls.
- Punitive creator/report actions and both appeal decisions reject absent, short, and overlong reasons.
- SQL contract tests preserve the creator-award notification, report-retain no-notification rule, content-removal notification, both appeal notifications, rejected-content notification, and new pending-to-approved publication notification.

### Full regression and browser acceptance

Run the complete Admin Portal, API, and Flutter test/analyse/build baselines. Then verify in the live local portal:

1. Assign creator reaches confirmation with no reason; Remove creator visibly requests a valid reason.
2. Retain content reaches confirmation with no reason; Remove content visibly requests a valid reason.
3. AI Approve reaches confirmation with no reason; AI Reject visibly requests a valid reason.
4. Appeals still require reasons for both decisions.
5. Confirmation cancellation changes no state.
6. Recent cards have no top media gap, retain visible borders while hovering, and lift without clipping.
7. Portrait and landscape images are completely visible inside Post Detail, with side controls and bottom dots intact.
8. AI queue tabs show no count badges.

Automated tests may confirm mocked/local decisions. Live checks against persistent records stop at the confirmation popup unless a safe test record or separate mutation approval is available.

## Documentation updates

After implementation, update `Project_Overview.md` and relevant setup/database documentation to record:

- The conditional decision-reason matrix.
- Notification behaviour for each administrator decision.
- The internal audit reason used for reason-free persisted actions.
- The real pending-to-approved system-notification foundation and the unchanged Gemini integration boundary.
- The corrected recent-card and Post Detail media behaviour.

Retain the existing project instruction that commands and tests for this repository are run directly in the user's PowerShell environment rather than a sandbox.

## Out of scope

- Gemini integration and a real AI-flagged queue.
- Redesigning the approved Administration Portal layouts.
- Reintroducing account suspension to Users.
- Changing report lifecycle states or the report reason chart.
- Applying repository SQL files to a remote Supabase database without separate explicit approval.
