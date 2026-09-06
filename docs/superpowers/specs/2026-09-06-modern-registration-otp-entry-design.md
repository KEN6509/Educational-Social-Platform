# Modern Registration OTP Entry Design

**Date:** September 6, 2026  
**Status:** Approved visual direction; pending implementation

## Purpose

Improve the mobile registration verification step without redesigning the surrounding CyanZone authentication screen or changing the existing Supabase six-digit OTP flow.

## Approved Visual Direction

The implementation follows revised Option A from the visual review:

- Keep CyanZone's current branded background, white authentication card, status message, primary button, and resend action.
- Place a borderless back arrow directly beside the `Enter the 6-digit code` heading.
- Show six equal rounded digit cells as one centered group.
- Use the existing CyanZone navy, teal, pale field background, typography, and corner-radius language.
- Highlight the active empty cell with the theme's teal focus treatment.

## Component Design

Add one focused reusable OTP input widget in the authentication presentation layer. It will expose a normal `TextEditingController`, change callback, submit callback, enabled state, and fixed six-digit length.

The widget will use one real numeric Flutter text input as the source of truth and render six visual cells from its value. This preserves:

- numeric keyboard input;
- full-code paste;
- Android OTP autofill;
- deletion and cursor progression;
- focus and disabled states;
- one accessible verification-code field instead of six unrelated controls.

The visual cell row will have a maximum width and remain horizontally centered. Cell width and spacing may reduce on narrow devices, but all six cells must stay on one line without overflow.

`EmailOtpPanel` will compose this widget and move its existing back action into the heading row. OTP verification, resend timing, controller ownership, and Supabase gateway behavior remain unchanged.

## Interaction and State

1. Opening the step focuses no field automatically; tapping anywhere on the six-cell group opens the numeric keyboard.
2. Each entered digit fills the next cell.
3. The active empty cell uses a teal border and subtle focus fill.
4. Non-numeric characters are rejected and input stops at six digits.
5. The Verify Email button becomes enabled only when all six digits are present.
6. Keyboard submission verifies only a complete six-digit code.
7. Back returns to the preserved registration form through the existing callback.
8. Existing loading, success, invalid-code, expired-code, resend, and countdown behavior stays intact.

## Error Handling

The OTP component performs only input-shape validation. Supabase remains responsible for deciding whether a complete token is valid or expired. Existing messages below the input continue to explain verification and resend outcomes.

## Testing

Focused widget regression tests will prove that:

- six visual cells render in one centered group;
- the back button is borderless and shares the heading row;
- digits, paste, deletion, numeric filtering, and the six-digit limit work;
- Verify Email and keyboard submission remain disabled for incomplete input and work for complete input;
- existing verification, resend, countdown, error, and Back flows remain functional.

Run the focused authentication tests and scoped Flutter analyzer. The full mobile suite is not required for this isolated presentation change.

## Out of Scope

- Changing Supabase's configured OTP length from six digits.
- Changing SMTP, email templates, registration consent, or activation SQL.
- Redesigning the full authentication page or CyanZone brand header.
- Adding a third-party OTP input dependency.

