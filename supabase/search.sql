-- Search Logs Table and Management
-- This table stores search history for users, limited to 20 entries per user.

create table if not exists public.search_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  query text not null,
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.search_logs enable row level security;

-- RLS Policies
create policy "Users can insert their own search logs" 
  on public.search_logs for insert 
  with check (auth.uid() = user_id);

create policy "Users can view their own search logs" 
  on public.search_logs for select 
  using (auth.uid() = user_id);

create policy "Users can delete their own search logs"
  on public.search_logs for delete
  using (auth.uid() = user_id);

-- Trigger to maintain 20 records limit per user automatically
create or replace function public.maintain_search_logs_limit()
returns trigger as $$
begin
  delete from public.search_logs
  where id in (
    select id
    from public.search_logs
    where user_id = new.user_id
    order by created_at desc
    offset 20
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger tr_maintain_search_logs_limit
after insert on public.search_logs
for each row execute function public.maintain_search_logs_limit();
