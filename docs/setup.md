# CyanZone Setup Notes

## Required Accounts

- Supabase project
- Google AI Studio or Google Cloud access for Gemini when AI moderation is implemented

Gemini moderation is planned for both text and images, but it is not connected
yet. The current application can run without a Gemini API key.

## Supabase Connection Values

Find these in Supabase project settings:

- Project URL
- Public anon key
- Service role key

Use the anon key in Flutter and React. Use the service role key only in the Express API.

Future Gemini credentials must also be stored only in the Express API
environment.

## Storage Buckets

Run these files in the Supabase SQL editor in order:

1. `supabase/storage.sql`
2. `supabase/schema.sql`
3. `supabase/auth.sql`

Storage setup creates:

- `avatars`: public profile pictures
- `images`: public post and chat images

Storage policies are intentionally prototype-oriented. Verify the deployed
policies before production use. Post deletion, image-message unsend, and final
group cleanup depend on the latest storage/chat SQL behavior.

## Database Script Order

After the base storage/schema/auth scripts, apply the incremental scripts needed
by the current mobile app. At minimum, the live project should include:

1. `supabase/search.sql`
2. `supabase/tags.sql`
3. `supabase/follow.sql`
4. `supabase/post_interactions.sql`
5. `supabase/post_editing.sql`
6. `supabase/comment_moderation.sql`
7. `supabase/comment_mentions.sql`
8. `supabase/chat.sql`

Inspect the remote schema before rerunning scripts. Notification trigger changes
do not backfill old Activity/New Followers rows.

## Current Notification Boundary

- In-app notification rows, unread dots, and badges use Supabase.
- External FCM/APNs push delivery is deferred to the next notification phase.
- Chat messages are not sent to Gemini moderation.
- `GEMINI_API_KEY` remains optional until post/comment moderation is connected.

## Local Tooling

Install these locally for development:

- Flutter SDK
- Node.js LTS with npm
- Git

The current scaffold is generator-free and can be opened directly in an editor.
