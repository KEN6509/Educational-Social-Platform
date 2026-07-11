-- Phase 4 post interaction polish.
-- Run this after storage.sql, schema.sql, auth.sql, search.sql, and tags.sql.

alter table public.likes
add column if not exists hidden_until timestamptz;

update public.likes
set hidden_until = created_at + interval '14 days'
where reaction_type = 'dislike'
  and hidden_until is null;

create index if not exists likes_active_dislike_idx
on public.likes (user_id, post_id, hidden_until)
where reaction_type = 'dislike';

create index if not exists comments_parent_created_idx
on public.comments (post_id, parent_comment_id, created_at);

alter table public.reports
drop constraint if exists reports_reason_length;

alter table public.reports
add constraint reports_reason_length
check (char_length(reason) between 3 and 120);
