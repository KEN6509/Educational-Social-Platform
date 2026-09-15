# Parent Supervision Historical Access Design

## Goal

Preserve appropriate Check-In and SOS history after a parent-child link is
revoked without allowing a former parent to see records created outside the
period when that relationship was active.

Password reauthentication is intentionally excluded. The existing two-party
unlink request, confirmation, acceptance, and rejection flow remains unchanged.

## Access Rules

- A child may continue reading their own Check-In and SOS records.
- A parent may read a child's Check-In or SOS record when its creation time is
  within one of their link periods: on or after `linked_at` and, for a revoked
  link, on or before `revoked_at`.
- An active parent link has no upper time boundary while it remains active.
- Rejected, cancelled, and pending links grant no historical-record access.
- Revocation immediately prevents the former parent from reading new Check-In,
  SOS, live-location, or SOS-event data.
- Screen-time reads remain active-link-only. Historical screen-time access is
  not added.
- SOS update, acknowledgement, and resolution operations remain active-link-only.
  Historical access is read-only.

## User Experience

- A user without an active Parent or Child role continues to see the unlinked
  Parent Supervision dashboard. No new records button is added there.
- Existing Supervision notifications remain available. Selecting a historical
  Check-In or SOS notification may open the referenced record when the current
  user owns it or was the parent during that record's active link period.
- The Child dashboard continues to omit the Safety Records page. Children open
  individual historical records from their Supervision notifications.
- While a user has an active Parent role, the existing Safety Records page may
  display records from current and former children. Supabase returns only
  records created during that parent's valid link periods.
- Missing or unauthorized notification targets continue to use the existing
  unavailable-record feedback.

## Database Design

The implementation extends the existing Row Level Security select policies for:

- `check_ins`;
- `sos_alerts`;
- `sos_live_locations`; and
- `sos_events`.

Each former-parent branch checks the record owner's child ID against
`parent_child_links`, requires a non-null `linked_at`, and compares the record's
creation time with the link window. For SOS locations and events, authorization
is derived through the parent `sos_alerts` row and its `created_at` value.

The design does not add a `link_id` to safety records. A child may have multiple
parents, so a single foreign key would not represent every authorized parent.
The existing time-window relationship data provides the required authorization
without duplicating records or creating archive copies.

The complete `supabase/parent_supervision.sql` and base `supabase/schema.sql`
definitions remain aligned. A focused, rerunnable incremental migration applies
the policy upgrade to existing Supabase projects.

## Security Boundaries

- Policy evaluation occurs in PostgreSQL; the Flutter application does not
  decide whether a former parent is authorized.
- A former parent cannot access records from before `linked_at` or after
  `revoked_at`.
- A later link to the same child creates another explicit authorization window.
- Becoming a parent again does not grant access to unrelated children or to
  records outside any valid parent-child window.
- Existing service functions continue requiring active relationships for every
  write or live supervision action.

## Testing

Automated SQL contract tests will verify:

- owners retain access to their own Check-In and SOS records;
- active parents retain current access;
- revoked parents receive read-only access inside the link window;
- records before `linked_at` and after `revoked_at` remain inaccessible;
- pending, rejected, and cancelled links grant no access;
- SOS live-location and event reads use the SOS creation time and relationship
  window;
- screen-time and all SOS mutation rules remain active-link-only; and
- the base schema, complete parent-supervision script, and incremental migration
  express the same policy.

Existing Flutter notification-routing and Safety Records tests remain the UI
regression baseline. Focused tests run first, followed by the complete Flutter
suite and static analysis.

## Deployment

After code review and merge, run the complete focused historical-access
migration in the Supabase SQL Editor. It is policy-only and rerunnable. Then use
two accounts to verify an in-window notification target remains readable after
unlinking and that a newly created child record is not visible to the former
parent.
