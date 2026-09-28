do $$
begin
  if exists (
    select 1
    from public.profiles
    where char_length(btrim(name)) not between 1 and 24
  ) then
    raise exception 'Profiles contain names outside the 1-24 character policy';
  end if;
end;
$$;

alter table public.profiles
  drop constraint if exists profiles_name_length_check;

alter table public.profiles
  add constraint profiles_name_length_check
  check (char_length(btrim(name)) between 1 and 24)
  not valid;

alter table public.profiles
  validate constraint profiles_name_length_check;
