# F001 Authentication Conformance and Password Policy Design

Date: July 31, 2026  
Status: Approved for implementation

## Objective

Complete the remaining F001 authentication gaps and strengthen all newly
created passwords without preventing existing users from logging in.

This change covers:

- logout confirmation in the Flutter mobile application;
- logout confirmation in the React Administration Portal;
- current-password verification on the mobile Change Password page;
- a shared password policy for mobile registration, mobile password changes,
  and administrator bootstrap;
- automated coverage for the security rules and mobile interaction flows; and
- an updated project overview and implementation priority.

After this work, the Administration Portal becomes the next implementation
priority. F002 completion, F006 completion, and AI moderation remain later
milestones.

## Password policy

Every newly created password must:

- contain at least 12 characters;
- contain at least one uppercase ASCII letter (`A-Z`);
- contain at least one lowercase ASCII letter (`a-z`);
- contain at least one ASCII number (`0-9`); and
- contain at least one non-letter, non-number, non-whitespace symbol.

The symbol rule deliberately includes period (`.`), underscore (`_`), and other
punctuation. A space does not satisfy the symbol requirement.

The policy applies to:

1. mobile account registration;
2. mobile password changes; and
3. administrator account creation through `POST /admin/bootstrap`.

Login does not apply the new-password validator. Existing accounts with older
passwords must remain able to authenticate.

## Mobile logout flow

Selecting **Log out** on the Settings page opens a confirmation dialog.

- **Cancel** closes the dialog and preserves the session.
- **Log out** calls Supabase sign-out and returns navigation to the root auth
  gate.
- While sign-out is running, duplicate confirmation actions are prevented.
- A failed sign-out keeps the user on the Settings page and shows a
  user-friendly error.

The dialog follows the current mobile visual language and uses a destructive
red treatment only for the confirmed Log out action.

## Administration Portal logout flow

Selecting **Sign out** opens a styled React modal instead of immediately signing
out or using the browser's native confirmation prompt.

- **Cancel** closes the modal and preserves the administrator session.
- **Sign out** calls Supabase sign-out.
- The confirmation action is disabled while the request is in progress.
- A failure closes neither the session nor the page and displays an inline
  error.

The modal uses the existing Administration Portal colors, typography, spacing,
and button styling.

## Mobile Change Password flow

The existing page is renamed visually from **Set Password** to
**Change Password**.

The input order is:

1. Current Password;
2. New Password; and
3. Confirm New Password.

The Current Password row reuses the existing password-input styling and appears
above the two existing rows.

Submission behavior:

1. Validate that all three fields are present.
2. Validate the new password against every password-policy rule.
3. Validate that the confirmation matches the new password.
4. Validate that the new password differs from the current password.
5. Reauthenticate with the current user's email and entered current password.
6. Confirm the reauthenticated user ID matches the current session user.
7. Update the password through Supabase Auth.
8. Show success feedback and return to Settings.

An incorrect current password displays a concise message without clearing the
new-password fields. Network/authentication failures display a retryable,
user-friendly message.

## Password guidance UI

Registration and Change Password display clear policy guidance.

The Change Password page shows a live checklist for:

- 12 or more characters;
- uppercase letter;
- lowercase letter;
- number; and
- symbol, including `.` or `_`.

Registration uses the same policy source and validation wording so the two
mobile flows cannot drift.

## Architecture

### Flutter

Create a small reusable password-policy utility under the authentication
feature or shared core layer. It returns individual rule results and one
validation message suitable for form validation.

Use injectable callbacks in the affected widgets so widget tests can verify
logout, reauthentication, and password update behavior without a live Supabase
session.

### Express API

Create an equivalent TypeScript password-policy utility. The administrator
bootstrap request schema calls it server-side before any account is created.
Client-side validation is not considered sufficient protection for the
bootstrap endpoint.

### React Administration Portal

Keep modal state within the current dashboard component. Do not add a router,
state library, or new UI dependency for this focused change.

## Error handling

- Missing fields: identify that every password field is required.
- Weak new password: identify the unsatisfied policy rules.
- Confirmation mismatch: explain that the two new passwords do not match.
- Reused password: require a different new password.
- Incorrect current password: state that the current password is incorrect.
- Missing authenticated email/session: require the user to log in again.
- Network or Supabase failure: preserve input and show a retryable message.
- Logout failure: keep the session/page and show an error.

Do not expose raw authentication internals, tokens, or sensitive server
messages in user-facing errors.

## Testing

### Flutter unit and widget coverage

- Passwords shorter than 12 characters fail.
- Missing uppercase, lowercase, number, or symbol fails independently.
- Period and underscore both satisfy the symbol rule.
- A fully valid password passes.
- Registration rejects weak passwords and accepts a policy-compliant password.
- Mobile logout Cancel does not call sign-out.
- Mobile logout confirmation calls sign-out exactly once.
- Incorrect current password prevents the update.
- A mismatched confirmation prevents reauthentication.
- A valid current password and valid new password perform verification before
  update.
- A new password equal to the current password is rejected.

### API coverage

- Administrator bootstrap rejects each invalid password category.
- Administrator bootstrap accepts period and underscore as symbols.
- The bootstrap handler cannot create an administrator before validation
  succeeds.

### Build and regression verification

- Run the full Flutter test suite.
- Run `flutter analyze`.
- Run the Administration Portal TypeScript and Vite production builds.
- Run the API tests and TypeScript build.

## Documentation updates

Update `Project_Overview.md` to:

- mark the completed F001 flows accurately;
- record the new password policy and its three enforcement points;
- retain the F002, F006, and AI-moderation backlog;
- clarify that message requests have backend foundations but lack recipient
  acceptance UI and end-to-end verification;
- describe the intended UC004 rule as one to five predefined tags; and
- make the Administration Portal the next implementation priority.

The source SRS should replace singular tag wording with:

> Users shall select between one and five tags from the predefined tag list
> when creating or editing a post. The `Others` tag may be selected when no
> suitable predefined tag applies. Creating, editing, or deleting predefined
> tags is outside the current project scope.

## Out of scope

- Password reset/forgot-password flows.
- Forced migration of existing passwords.
- Multi-factor authentication beyond the separate F002 OTP requirement.
- Message-request acceptance implementation.
- Administration Portal feature expansion beyond the logout confirmation.
- F002, F006, and AI moderation implementation.
