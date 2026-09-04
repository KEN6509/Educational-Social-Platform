# Registration Consent and Email OTP Design

Date: 2026-09-04
Status: Approved for implementation planning

## Context

CyanZone currently supports email and password registration, but registration does not yet require legal consent or verify an email through an OTP entered inside the app. The project already has an `AuthGateway`, a Supabase implementation, dependency composition through `AppDependencies`, and an `AuthGate`. This feature will extend those boundaries instead of introducing direct Supabase calls in presentation widgets.

## Goals

- Require every new user to accept the current Terms and Conditions and Privacy Policy before registration.
- Provide concise version 1.0 Terms and Privacy pages inside the mobile app.
- Record the accepted document versions and acceptance time for each new verified profile.
- Use Supabase Confirm Email with a numeric OTP entered inside CyanZone.
- Support verification, resend after 60 seconds, wrong-email correction, and recovery after an app restart.
- Prevent unverified users from entering protected CyanZone functions.
- Prevent abandoned unverified registrations from appearing as public profiles.
- Preserve existing accounts without forcing them through a new retrospective consent screen during this MVP.

## Non-goals

- Automatically deleting abandoned Supabase Auth users.
- Background jobs or server-side account cleanup.
- Requiring existing users to accept version 1.0 retroactively.
- A legal-document content management system.
- Social login, phone OTP, password recovery, or multi-factor authentication.
- A broad authentication or mobile UI refactor unrelated to this registration flow.

## Clarification About Existing Users

All new registrations must accept the checkbox before the registration request can be submitted. The accepted Terms version, Privacy version, and timestamp will be stored.

Profiles created before this feature may have null consent columns because those users registered before CyanZone started recording consent. They will remain usable during the MVP and will not be unexpectedly locked out. A future policy migration can request consent from those users if the project later requires it.

## Considered Approaches

### 1. Extend the existing Supabase-native authentication flow

This is the selected approach. The mobile app registers through `AuthGateway`, Supabase sends the confirmation OTP, and the app verifies or resends it through the same gateway. A small local store remembers only the pending email address.

This approach fits the current architecture, uses Supabase security controls, and is appropriate for the MVP.

### 2. Use a separate navigation route for every registration step

Dedicated form and OTP routes could make each widget smaller, but they add route-state recovery and controller handoff complexity. The existing authentication page can represent these states without introducing unnecessary navigation infrastructure.

### 3. Build a server-owned registration API

A custom server could control pending accounts and immediately delete abandoned registrations. It would also require secure service-role handling, deployment, monitoring, and more tests. That workload is not justified for the MVP.

## User Flow

### Registration form

1. The user enters their name, email, password, and password confirmation.
2. One unchecked consent control states that the user agrees to the Terms and Conditions and Privacy Policy.
3. Each document name is an interactive link that opens its own in-app document page.
4. Registration validation fails with a clear message until consent is accepted.
5. On submission, the app captures the current document versions and a UTC acceptance timestamp.
6. The app calls the gateway with the normalized email, registration fields, and consent metadata.
7. When Supabase reports that confirmation is required, the app remembers the pending email and displays the OTP state.

### OTP verification

1. The page clearly displays the submitted email address.
2. The OTP field accepts exactly six numeric digits.
3. `Verify Email` remains disabled until six digits are present.
4. A resend countdown starts at 60 seconds.
5. When the countdown reaches zero, `Resend code` becomes enabled.
6. A successful resend clears the OTP field, confirms that a new code was sent, and restarts the countdown.
7. Successful verification clears the locally stored pending email. The verified Supabase session then allows `AuthGate` to enter the application.

### Correcting a wrong email

1. Back from the OTP state returns to the registration form.
2. The name, email, and other form values remain available during the current app session so the user only needs to correct the email.
3. The locally remembered pending email is cleared.
4. The earlier remote unverified Auth account is not deleted by the mobile app.
5. Submitting the corrected email creates a separate registration attempt.

### Restart and login recovery

- If CyanZone restarts while a pending email is stored, the authentication page reopens in the OTP state.
- Only the normalized email is stored. Passwords and OTP values are never persisted.
- If login fails because the email is not confirmed, the app moves that email into the OTP flow and allows the user to resend the signup code.

## Architecture

### Domain authentication contract

Extend `AuthGateway` with explicit operations for:

- Registering from a registration request that includes name, email, password, consent versions, and acceptance time.
- Verifying a signup OTP for an email address.
- Resending a signup OTP for an email address.

Authentication failures continue to cross the boundary as safe domain failures rather than leaking Supabase-specific exceptions into the UI.

The signed-in state exposed by the gateway must require both a valid session and a confirmed email. This makes the activation rule explicit even if a session shape changes or a test fake supplies an unverified user.

### Supabase adapter

`SupabaseAuthGateway` will:

- Send the name and consent audit values in signup metadata.
- Map a signup response with no session to `RegistrationOutcome.confirmationRequired`.
- Verify the code with the SDK signup OTP type.
- Resend using the SDK signup OTP type.
- Convert invalid, expired, rate-limited, and network failures into safe messages.

No service-role key or admin authentication API will be added to the mobile application.

### Pending registration store

Add a small `PendingRegistrationStore` interface and a SharedPreferences-backed implementation. It has three responsibilities:

- Read the pending normalized email.
- Save the pending normalized email.
- Clear the pending normalized email.

The store is composed through `AppDependencies`. Tests can use an in-memory fake without initializing SharedPreferences.

### Registration state

The authentication presentation layer will use an explicit registration state instead of several unrelated booleans. The relevant states are:

- Editing the form.
- Submitting registration.
- Awaiting OTP.
- Verifying OTP.
- Resending OTP.
- Failure while remaining on the current step.

The current form controllers remain alive when moving between the form and OTP states during one app session.

### Legal documents

Add reusable legal-document presentation components with separate Terms and Privacy content. Both documents use simple English and show version 1.0 with an effective date. Policy version constants are defined outside the widgets so the displayed version and stored version cannot drift apart.

## Data Design

Add these nullable columns to `public.profiles`:

- `terms_version text`
- `privacy_version text`
- `consent_accepted_at timestamptz`

They are nullable so existing profiles remain valid. New registration metadata contains all three values.

The profile trigger behavior changes as follows:

- An Auth user inserted with a confirmed email can receive a profile immediately.
- An Auth user inserted without confirmation does not receive a public profile yet.
- When `email_confirmed_at` becomes non-null, a trigger creates the profile and copies the name and consent metadata.
- Profile creation is idempotent so a repeated applicable event does not create a duplicate profile.
- The profile privilege-protection trigger prevents a normal user from manually rewriting the consent audit columns.

This avoids showing abandoned unverified registrations in searches or other features that query `public.profiles`.

## Error Handling

- Missing consent: stay on the registration form and show a validation message near the consent control.
- Invalid or expired OTP: stay on the OTP state and show an inline error.
- Network error during verification: retain the entered code so the user can retry.
- Registration or resend rate limit: show a safe user-facing message and do not falsely report success.
- Successful resend: clear the previous code and restart the 60-second countdown.
- Unconfirmed login: move to the OTP state and offer resend instead of showing only a generic login failure.
- Verification or transactional profile-provisioning failure: remain in the OTP flow and show a recoverable error. The database trigger runs as part of confirmation, so a trigger failure must not be presented as a completed verification.

## Supabase Dashboard Configuration

The hosted project must be updated manually because this workspace has no connected Supabase CLI project or dashboard credentials.

The implementation handoff will provide exact instructions to:

1. Enable Confirm Email for the Email provider.
2. Edit the Confirm Signup email template to display the token variable rather than relying only on a confirmation link.
3. Save the template and send a test registration.
4. Run the provided database SQL changes in the Supabase SQL Editor.

## Testing and Verification

Verification will be focused rather than running every project test:

- Gateway tests for signup metadata, confirmation-required outcomes, OTP verification, OTP resend, and safe error mapping.
- Pending-store tests for read, save, and clear behavior.
- Authentication gate tests proving unverified accounts cannot enter protected functions.
- Widget tests proving consent is mandatory and both legal links open the correct documents.
- Widget tests for OTP input, verification, resend countdown, resend success, errors, back navigation, and restored pending email.
- SQL review for idempotent profile creation and protection of consent audit fields.
- Scoped `flutter analyze` for the affected mobile authentication files.

## Acceptance Criteria

- A new user cannot submit registration without accepting the combined consent control.
- Terms and Privacy content is readable inside CyanZone.
- A submitted registration displays the correct email on the OTP page.
- The user can verify a valid signup OTP and then access the application.
- An invalid or expired OTP does not activate the account.
- Resend is unavailable for 60 seconds and works when the countdown completes.
- Back allows the user to correct an email without pretending that the remote unverified account was deleted.
- A pending email restores the OTP state after an app restart.
- New verified profiles contain version 1.0 Terms and Privacy acceptance data and a UTC timestamp.
- Unverified Auth users do not appear as public profiles.
- Existing profiles with null consent fields continue to work during the MVP.

## Future Improvements

Automatic cleanup of abandoned unverified Auth accounts remains outside this MVP and is recorded in `docs/Future_Improvements.md`. That document also records background SOS location tracking while CyanZone is minimized or the phone is locked.
