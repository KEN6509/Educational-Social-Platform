# Parent Supervision Dashboard Grid Refinement

Date: 3 August 2026
Status: Approved

## Scope

Refine the existing Parent Supervision dashboard and account-link request sheet without changing parent/child role semantics, Check-In, SOS, records, notification destinations, or backend authorization rules.

## App bar

The Parent Supervision page will use the same app-bar pattern as `chat_page.dart`:

- white background;
- zero elevation and zero scrolled-under elevation;
- left-aligned title with 16 logical pixels of title spacing;
- title `Parent Supervision` in `0xFF0B1F3E`, 24 logical pixels, weight 800;
- a plain 28-pixel person-add `IconButton` in `0xFF0B1F3E`;
- 8 logical pixels of trailing spacing.

The add-family-link entry point remains a bottom sheet.

## Request account linking sheet

The add action continues to open a bottom sheet. Its account list adopts the existing New Followers page treatment shown in `notification_sections_page.dart` and the approved reference `C:\Users\KEN\AppData\Local\Temp\codex-clipboard-eed7b97c-bb83-4820-85fe-c651a74cb7db.jpg`.

- The sheet title is left-aligned and reads `Request Account Linking`.
- The existing search field remains above the account list.
- Each row uses a 46-pixel circular avatar, a bold account name, the follow relationship as secondary text, and a divider indented past the avatar.
- Available accounts show a rounded cyan button with white `Request` text.
- Accounts with an outgoing or incoming pending family-link request show a disabled soft-gray `0xFFF1F5F9` button with cyan `Pending` text.
- Existing active family links remain unavailable for another request and use the same quiet disabled treatment with an accurate state label.
- A successful request keeps the sheet open and changes that account to `Pending` immediately. Closing the changed sheet refreshes the dashboard.
- Loading, error, empty, search, eligibility, and large-text states remain visible and usable.

The unlinked-user role prompt uses `AppConfirmationDialog`, matching the shared Log out confirmation surface, spacing, typography, radius, and actions. The filled cyan primary action is text-only `Child`; the secondary action is text-only `Parent`. Neither action contains an icon. The dialog's existing top illustrative icon may remain because it is part of the shared confirmation structure. Users with an established family role continue to skip this prompt.

## Responsive card grid

The dashboard uses a two-column grid with 16 logical pixels of outer horizontal padding and 12 logical pixels between columns. The half-width column size is the shared dashboard-card height:

`tileExtent = (available dashboard width - column gap) / 2`

This creates the following rules:

- each card displayed in a two-card row is square;
- the full-width My screen time card has height `tileExtent`;
- a full-width Family links card has height `tileExtent`;
- linked-parent Family links and Check-In & SOS records cards form one row of two square cards;
- linked-child Safety Check-In and SOS cards form one row of two square cards;
- the linked-child Family links card remains full-width and uses height `tileExtent`;
- the unlinked Family links card remains full-width and uses height `tileExtent`.

The fixed 190-pixel internal content area and its large `Spacer` are removed. Card content uses compact, deliberate spacing so descriptions and bottom actions do not appear disconnected.

Supervision notifications are excluded from the shared-height rule because the card contains a variable list of zero to ten updates and must remain content-driven.

## Card content

Summary and safety cards retain the approved visual language: white surface, rounded border, pale-cyan icon container, navy title, secondary description, and bottom action/chevron. Content must fit a square tile at 360 logical pixels without clipping or overflow.

Safety Check-In and SOS keep their existing enabled state and callbacks. Their presentation changes from wide horizontal cards to square grid cards only.

## Color

The dashboard canvas and light-gray notification/empty-state fills use `0xFFF1F5F9` to match the mobile app theme. White card surfaces, borders, semantic SOS red, Check-In green, notification green, cyan icon surfaces, and navy text remain unchanged.

## Testing

Widget regressions will verify at 360 logical pixels that:

- the app-bar title and action match the Chat page pattern;
- the dashboard canvas uses `0xFFF1F5F9`;
- the screen-time and full-width Family links cards have equal heights;
- parent Family links and records cards are square, equal-sized, and share a row;
- child Safety Check-In and SOS cards are square, equal-sized, and share a row;
- the screen-time height equals the square grid-card height;
- no layout exception occurs.

Linking-sheet regressions will verify that:

- the left-aligned title reads `Request Account Linking`;
- rows match the New Followers structure with an indented divider;
- an available account has a cyan `Request` action;
- a request changes the action to soft-gray `Pending` without closing the sheet;
- existing pending links reopen as `Pending`;
- the role prompt uses `AppConfirmationDialog` with text-only `Child` and `Parent` actions;
- established roles still bypass the role prompt;
- the sheet remains layout-safe at 360 logical pixels with 2× text scaling.

Existing linking, safety-flow, notification-limit, navigation, full-suite, and analyzer checks must remain green.
