# Comment Moderation Feedback and Shared-Post Radius Design

## Scope

This change makes two small mobile improvements without changing moderation rules, chat data, or the appearance of normal text and image messages.

## Comment feedback

- Apply the same flow to top-level comments and replies.
- After the comment record is created successfully, immediately show the shared white feedback snackbar with: `Comment submitted. AI moderation is checking it.`
- Keep the comment hidden while moderation is pending. It appears publicly only after AI moderation approves it.
- Continue the existing moderation request after showing the pending feedback.
- Replace the pending feedback with the final approved, rejected, administrator-review, processing, or retry feedback. Do not queue multiple snackbars.
- If creating the comment fails, show the existing error feedback and do not show the pending message.

## Shared-post chat card

- Keep the existing chat bubble outer corner radius of 16 dp.
- Keep the existing 4 dp inset around rich message content.
- Change the nested shared-post card radius from 8 dp to 12 dp so it follows `inner radius = outer radius - inset`.
- Apply the corrected radius to shared posts with and without images, for both sent and received messages.
- Do not change ordinary text messages or image-message presentation.

## Testing

- Add a focused regression test confirming that comment submission shows the pending-moderation feedback after successful creation and before moderation completes.
- Cover the shared flow used by both comments and replies.
- Extend the shared-post widget test to verify the 12 dp inner card radius while preserving the 16 dp outer bubble radius.
- Run the focused post-comment and chat-widget tests, followed by Flutter analysis.

## Out of scope

- Optimistic display of unapproved comments.
- Changes to Gemini moderation rules or API behavior.
- Redesigning normal chat text bubbles or image messages.
