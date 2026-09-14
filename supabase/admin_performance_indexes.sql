-- Indexes used by the administrator portal read queues.

create index if not exists profiles_admin_created_idx
on public.profiles (is_admin, created_at desc);

create index if not exists creator_requests_status_created_idx
on public.content_creator_requests (status, created_at desc);

create index if not exists moderation_cases_state_created_idx
on public.content_moderation_cases (state, created_at desc);
