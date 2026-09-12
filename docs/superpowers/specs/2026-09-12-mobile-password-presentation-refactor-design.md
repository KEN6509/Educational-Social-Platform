# Mobile Password Presentation Refactor Design

## Context

Phase 5C completes the mobile profile presentation refactor. The Change
Password page still owns its Supabase workflow, input state, validation,
temporary feedback, and all presentation code in one file. The page currently
works, so this phase must improve structure and consistency without changing
the password flow or redesigning the screen.

## Goals

- Keep the existing Change Password behaviour and visual layout.
- Keep authentication and password-update coordination in the page state.
- Move reusable, stateless presentation into a feature-local Dart part file.
- Use the shared CyanZone feedback component and exact design tokens.
- Add regression tests that protect behaviour and file ownership.

## Non-Goals

- No new password feature or recovery flow.
- No changes to Supabase Auth, database policies, API services, or deployment.
- No Riverpod or new package dependency.
- No broad UI redesign.
- No changes to the existing password rules or wording.

## Architecture

`set_password_page.dart` remains the workflow coordinator. It owns the three
controllers, password-policy state, processing state, session lookup,
reauthentication, password update, success navigation, and error mapping.

`set_password_widgets.dart` becomes a private part of the page library. It
owns the immutable form body, password input field, guidance text, and bottom
submit action. The widgets receive values and callbacks and do not access
Supabase or construct repositories.

The existing shared `PasswordChecklist` remains in `core/widgets` because it
is already reused by registration and Change Password.

## Components

### SetPasswordPage state

- Coordinates validation in the existing order.
- Resolves the current signed-in email and user ID.
- Reauthenticates before changing the password.
- Prevents duplicate submissions while processing.
- Updates the live `PasswordPolicyResult` when the new password changes.
- Shows feedback through `AppFeedback`.

### Password presentation part

- `_SetPasswordBody` lays out the three fields, checklist, guidance, and
  submit action.
- `_PasswordInput` renders one labelled obscured password field.
- `_PasswordGuidance` renders the existing current-password difference note.
- `_PasswordSubmitButton` preserves the current label, disabled state,
  progress indicator, size, and radius.

## Data Flow

1. The user edits the new-password field.
2. The page state evaluates it with `PasswordPolicy` and rebuilds the body.
3. The user selects Done.
4. The page state validates all fields, policy compliance, confirmation, and
   difference from the current password.
5. The page state reauthenticates the current user.
6. The page state updates the password only after reauthentication succeeds.
7. Success feedback is shown and the page closes. Failures keep the page open
   and restore the enabled button.

## Error Handling

All temporary messages use the existing white floating `AppFeedback` style.
Validation, incorrect-password, expired-session, verification, and update
messages retain their current text. The page must remain mounted before UI
feedback, state updates, or navigation is performed after asynchronous work.

## Design Consistency

Exact existing values are replaced only when a matching shared token already
exists. This includes page horizontal padding, navy, secondary text, muted
text, and page vertical spacing. The existing 12px control radius remains
unchanged because the current shared radius tokens do not have the same value.

## Testing

- Structural tests prove that the presentation classes live in
  `set_password_widgets.dart`, not the page file.
- Structural tests reject Supabase access and direct SnackBar construction in
  the presentation part.
- Existing tests continue to cover validation order, reauthentication,
  password update, failure handling, and processing state.
- A feedback regression verifies that a validation error uses the shared
  floating feedback presentation.
- The complete mobile test suite, analyzer, strict formatter, and Git
  whitespace check form the automated completion gate.

Physical Android testing remains deferred until all Phase 5 work is complete.
