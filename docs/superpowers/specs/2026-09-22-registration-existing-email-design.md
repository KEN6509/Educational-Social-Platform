# Existing Registration Email Handling

## Problem

When email confirmation is enabled, Supabase can return a successful-looking, sessionless signup response for an email that already belongs to a confirmed account. The mobile app currently reduces every signup response to whether it contains a session, so it mistakes that protected duplicate response for a new registration and navigates to the OTP screen.

## Desired behavior

- A confirmed existing account stays on the registration form.
- The email field displays: `An account with this email already exists.`
- The app does not save a pending registration or open the OTP screen for that response.
- A new registration that requires confirmation continues to the OTP screen.
- An existing but unverified registration also continues to the OTP screen so the user can complete verification.
- Editing the email clears the server-side duplicate error.

## Design

The Supabase adapter will preserve enough of the signup response to distinguish three outcomes:

1. A response with a session is an immediately signed-in registration.
2. A sessionless response whose user has an empty identities list is Supabase's protected response for an already-confirmed account.
3. Other sessionless responses require email confirmation and proceed to OTP.

The authentication gateway will translate those adapter outcomes into the existing domain boundary. The duplicate outcome will become an `AuthFailure` with a dedicated `emailAlreadyRegistered` reason and the user-facing message above. The registration controller will keep that failure associated with the email field instead of treating it as a general form message.

The registration page will pass the field error into the email input, render it directly under that input, and clear it as soon as the user edits the email. Existing validation for malformed email addresses remains higher priority than the server-side duplicate result.

## Error handling

Network, rate-limit, OTP, and unexpected authentication failures retain their current behavior. Only the known duplicate-email response receives field-level treatment. No public profile query or privileged user lookup is introduced.

## Tests

- Adapter/gateway tests will prove that an empty identities list maps to `emailAlreadyRegistered`.
- Gateway tests will prove that a normal sessionless signup remains `confirmationRequired`.
- Controller tests will prove that a duplicate stays in the editing phase and does not persist a pending email.
- Widget tests will prove that the message appears under the email field, OTP is not shown, and changing the email clears the message.
- Existing OTP tests will continue to prove that new and unverified registrations can proceed.

## Scope note

The pre-existing `supabase/tags.sql` cleanup will be preserved and included in the implementation branch as explicitly requested, but it is functionally independent from this authentication fix.
