# CyanZone Setup Notes

## Required Accounts

- Supabase project
- Google Cloud project with Perspective API access

## Supabase Connection Values

Find these in Supabase project settings:

- Project URL
- Public anon key
- Service role key

Use the anon key in Flutter and React. Use the service role key only in the Express API.

## Storage Buckets

Run these files in the Supabase SQL editor in order:

1. `supabase/storage.sql`
2. `supabase/schema.sql`
3. `supabase/auth.sql`

Phase 1 creates:

- `avatars`: public profile pictures
- `post-images`: public post images

Storage policies are intentionally kept simple for the prototype. Phase 2 will align policies with the final database schema and authenticated user ownership.

## Local Tooling

Install these locally for development:

- Flutter SDK
- Node.js LTS with npm
- Git

The current scaffold is generator-free and can be opened directly in an editor.
