# Mobile UI Consistency and Badge Stability Design

## Goal

Refine four mobile-app behaviors without changing backend contracts: standardize every existing confirmation dialog, align text-post moderation badges with image-post badges, prevent the Messages unread badge from blinking during tab entry, and reuse one live password checklist on registration and password change.

## Scope

### Included

- Replace every existing mobile confirmation layout with one shared dialog based on the current Delete Post dialog.
- Preserve each action's existing wording, icon meaning, destructive or standard tone, async operation, and success/error handling.
- Place Pending and Rejected badges at the top-left of both text and image post cards with the same inset and pill appearance.
- Keep the Messages navigation badge at its last known value while entering the Messages page or while a refresh temporarily fails.
- Reuse one live password checklist in Change Password and User Registration.
- Change the symbol guidance to `!, @, #, $, %, or &` as examples only.
- Keep accepting any non-whitespace symbol, including `.` and `_`.

### Excluded

- Supabase schema, RLS, API, notification-count, or password-policy validation changes.
- New confirmation flows, new password rules, registration OTP, or consent work.
- Visual redesigns outside the affected confirmation dialogs, post badges, Messages badge, and password checklists.

## Shared Confirmation Dialog

Create a reusable mobile confirmation API under `apps/mobile/lib/src/core/widgets/`. It owns the full presentation and returns a boolean result to the caller.

The fixed presentation contract is:

- barrier color: black at 42% opacity;
- transparent route dialog background;
- 28-pixel horizontal inset;
- white card with 22-pixel corner radius and the existing soft shadow;
- centered 58-pixel circular icon treatment;
- centered title and explanatory message;
- full-width 48-pixel primary action;
- full-width 42-pixel Cancel action below the primary action;
- destructive or standard appearance supplied through icon and action colors, without allowing callers to redefine layout.

The shared helper accepts the context, icon, icon foreground/background colors, title, message, primary label, and primary color. It returns `Future<bool?>`. Callers continue to perform their own network or repository operation only after a `true` result.

Migrate the current confirmation surfaces:

- mobile logout;
- post update and post deletion;
- message delete-for-me and unsend;
- clear chat, exit group, and related chat danger actions;
- group-member removal;
- notification deletion from the System list and detail page;
- SOS submission.

Existing action-specific keys needed by widget tests remain available on the shared dialog's primary action.

## Post Moderation Badge Layout

Image cards already establish the reference: a status pill positioned eight pixels from the top and left edges of the card's main visual region.

Text-only cards will position the same `_StatusBadge` relative to the complete card content rather than the inner text surface. The text layout reserves vertical space when a Pending or Rejected badge is present so the pill never overlaps the title. Approved cards keep their existing compact spacing. Badge wording, icon, colors, and moderation rules remain unchanged.

## Messages Badge State

The current blink is caused by `MainShell` setting `_chatBadgeCount` to zero as soon as the Messages tab is selected, followed by an asynchronous refresh that restores the real value.

Remove tab selection as a badge mutation. Opening Messages changes only the selected navigation index. The badge changes only when a successful unread-count load or the existing `ChatPage.onBadgeCountChanged` callback provides a new count.

If `_refreshChatBadge` fails, it preserves the last known count. It does not infer that a network error means zero unread items. This prevents both the deterministic tab-entry blink and transient network-error flicker.

## Shared Password Checklist

Move the checklist presentation out of `set_password_page.dart` into a reusable widget under `apps/mobile/lib/src/core/widgets/`. It consumes `PasswordPolicyResult` and renders the five existing live rules with green completed and grey incomplete states.

The final labels are:

1. At least 12 characters
2. Contains an uppercase letter
3. Contains a lowercase letter
4. Contains a number
5. Contains a symbol such as !, @, #, $, %, or &

Change Password continues updating the checklist from the New Password field. Registration adds local password-policy state and updates the shared checklist on every password-field change. Login mode does not display the checklist.

`PasswordPolicy.hasSymbol` remains based on any non-whitespace, non-alphanumeric character. The validation message uses the new examples but does not restrict the accepted symbol set.

## Error Handling

- Confirmation cancellation performs no action.
- Repository and authentication failures retain their existing screen-level feedback.
- A failed Messages badge refresh preserves the last successful or cached count.
- Password validation continues using the shared `PasswordPolicy`; the checklist is guidance and does not replace form validation.

## Testing Strategy

Use test-driven development for each behavior:

- Add shared confirmation widget tests for layout, primary action, Cancel, and optional test keys.
- Update logout and existing confirmation regressions to target the shared component rather than `AlertDialog`.
- Add a feed-card regression proving text and image badges use the same top-left inset and that the text badge does not overlap the title.
- Add a shell regression proving selecting Messages does not zero the current badge and a failed refresh preserves the previous value.
- Add registration widget tests proving the checklist is visible only in registration mode and updates as rules become valid.
- Update Change Password and password-policy tests for the new symbol examples.
- Retain tests proving period and underscore passwords are valid.
- Run focused tests after each red/green cycle, then run the complete Flutter test suite, `dart format`, and `flutter analyze` directly in the user's PowerShell environment.

## Acceptance Criteria

- Every current mobile confirmation uses the shared Delete Post-style layout.
- Text and image post status pills appear at the top-left with matching styling and spacing.
- Entering Messages never temporarily clears a valid unread badge.
- A transient unread refresh failure never replaces the last known badge with zero.
- Registration and Change Password show the same live checklist.
- Both screens show the new symbol examples.
- All non-whitespace symbols remain valid under the password policy.
- Focused and full Flutter verification passes with no analyzer issues.
