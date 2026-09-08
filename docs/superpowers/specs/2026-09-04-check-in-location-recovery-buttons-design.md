# Check-In Location Recovery Buttons Design

## Context

When location capture fails, the Safety Check-In recovery container currently shows an intrinsic-width **Retry location** button beside an expanded **Continue without location** button. The mismatched widths and heights make the actions look unbalanced on a phone-sized screen.

## Approved Design

- Keep the recovery actions side by side so the container remains compact.
- Give both actions equal available width with an 8dp gap.
- Give both actions a minimum height of 52dp and allow them to grow together if accessibility text scaling requires more space.
- Keep **Retry location** as the outlined secondary action.
- Rename the filled action to **Send without location** so it accurately communicates that tapping it immediately submits the Check-In.
- Use centered labels with up to two lines and matching button corner geometry.
- Preserve the current loading/disabled behavior and submission logic.

## Verification

Add a focused widget test that enters the location-unavailable state on a narrow phone viewport and verifies:

- both actions are present;
- both buttons have equal width and height;
- each touch target is at least 48dp high;
- the revised **Send without location** label is shown;
- the layout produces no overflow exception.

