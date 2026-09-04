# Feature-Enabling Architecture Foundation Design

## Context

CyanZone has three remaining implementation areas: registration consent/OTP, real Gemini moderation for mobile and the Administration Portal, and FCM push delivery. The Express API and Administration Portal already use explicit dependency boundaries in their important paths, while Flutter presentation widgets still access the global Supabase singleton and construct concrete repositories in many places.

A full mobile dependency rewrite before completing the remaining features would be too broad. Conversely, adding the three integrations directly to presentation widgets would make the later refactor larger and riskier. This foundation therefore establishes one production composition point and proves the pattern on authentication, the next feature area.

## Scope

This phase will:

- create an application-owned authentication contract;
- adapt Supabase Auth to that contract;
- construct the production dependency in one composition root;
- inject authentication into `CyanZoneApp`, `AuthGate`, and `AuthPage`;
- remove Supabase SDK imports and singleton access from authentication presentation code;
- preserve current login, registration, validation, success messaging, session gating, and authenticated navigation behavior;
- add focused tests for dependency injection, login/registration delegation, error presentation, and authentication-state observation;
- document how later external providers must enter the system.

This phase will not:

- implement consent, OTP entry, Gemini calls, moderation decisions, Firebase configuration, or push delivery;
- migrate every existing mobile repository construction point;
- redesign authentication UI;
- change the existing Administration Portal or Express API implementation where their dependency injection is already adequate;
- introduce Riverpod or another state-management dependency.

## Mobile Structure

```text
apps/mobile/lib/src/
  app_dependencies.dart                         Production composition model
  features/auth/domain/auth_gateway.dart         App-owned auth contract and values
  features/auth/data/supabase_auth_gateway.dart  Supabase Adapter
  features/auth/presentation/auth_gate.dart      Session Observer
  features/auth/presentation/auth_page.dart      UI using the contract
```

### Authentication contract

`AuthGateway` will expose only application concepts required by current behavior:

- the current signed-in state;
- a stream of signed-in state changes;
- password login;
- name/email/password registration;
- whether registration immediately created a session or requires email confirmation.

The presentation layer will handle an app-owned `AuthFailure` containing a safe user-facing message. Supabase types such as `AuthState`, `Session`, `AuthResponse`, and `AuthException` will not cross into presentation files.

### Supabase adapter

`SupabaseAuthGateway` will implement `AuthGateway` and be the only new authentication file that imports `supabase_flutter`. It will:

- map `currentSession != null` to `isSignedIn`;
- map `onAuthStateChange` to a distinct `Stream<bool>`;
- delegate password login and registration to Supabase;
- map a registration response with no session to `confirmationRequired`;
- convert expected `AuthException` values into `AuthFailure` and allow unexpected failures to reach the presentation layer's existing generic-error handling.

### Composition root

`main.dart` will remain responsible for Supabase initialization and will then construct `AppDependencies.production(Supabase.instance.client)`. `CyanZoneApp` will require this dependency object and pass its `AuthGateway` into `AuthGate`. Tests will construct `AppDependencies` with a fake gateway rather than initializing and relying on a global Supabase singleton.

`AppDependencies` acts as the application-level construction facade. It will initially contain only authentication; future dependencies are added only when their real feature is implemented.

### Presentation flow

`AuthGate` remains the authentication-state Observer. It reads `isSignedIn` for the initial state and listens to `signedInChanges` for subsequent login/logout transitions. When signed out it creates `AuthPage(authGateway: ...)`; when signed in it preserves the existing `SosTrackingHost(child: MainShell())` destination.

`AuthPage` preserves its current form and validation. Submission calls `AuthGateway.signIn` or `AuthGateway.register`. `AuthFailure.message` is displayed as the specific authentication error; unexpected errors retain `Something went wrong. Please try again.` Registration without a session retains the current email-confirmation success message.

## Pattern Rules for Remaining Features

- **Adapter:** Supabase Auth, Gemini, and Firebase SDK details stay inside concrete adapters implementing application-owned contracts.
- **Facade / Composition Root:** Concrete production dependencies are created at an application boundary rather than inside presentation widgets.
- **Observer:** UI reacts to authentication, realtime, and push streams through app-owned values rather than provider-specific event objects.
- **State:** The registration consent/OTP implementation will model explicit registration states instead of adding loosely related booleans to the page.
- **Strategy:** Gemini risk thresholds and moderation decisions will be isolated from the Gemini transport adapter.

Gemini will have one server-side moderation implementation in `services/api`. Mobile submission flows and the Administration Portal will consume that shared backend workflow; neither client will call Gemini directly. FCM credentials and delivery also remain server-side, while the mobile Firebase adapter handles device permission, token lifecycle, and received-message events.

## Verification

Focused tests will prove that:

- signed-out app startup displays the authentication UI using an injected fake;
- login delegates normalized email and password to the gateway;
- registration delegates name/email/password and preserves confirmation-required messaging;
- app-owned authentication failures remain visible to the user;
- an emitted signed-in state replaces the authentication page with the authenticated destination;
- authentication presentation files contain no Supabase import or singleton access;
- existing authentication widget behavior and scoped Flutter analysis remain clean.

## Migration Safety

This refactor changes dependency construction only. It does not alter Supabase schema, credentials, authentication settings, or production data. Existing unrelated mobile repositories continue using their current construction paths until a remaining feature provides a concrete reason to migrate them.
