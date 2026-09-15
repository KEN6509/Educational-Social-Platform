-- Preserve read-only Check-In and SOS history for former parents.
-- Safe to rerun after parent_supervision.sql on an existing project.

drop policy if exists "Family can view check-ins"
on public.check_ins;
drop policy if exists "Active family views child safety records"
on public.check_ins;
drop policy if exists "Family views child safety records"
on public.check_ins;
create policy "Family views child safety records"
on public.check_ins for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = check_ins.user_id
      and link.linked_at is not null
      and link.linked_at <= check_ins.created_at
      and (
        link.status = 'active'
        or (
          link.status = 'revoked'
          and link.revoked_at is not null
          and check_ins.created_at <= link.revoked_at
        )
      )
  )
);

drop policy if exists "Family can view sos alerts"
on public.sos_alerts;
drop policy if exists "Active family views child SOS records"
on public.sos_alerts;
drop policy if exists "Family views child SOS records"
on public.sos_alerts;
create policy "Family views child SOS records"
on public.sos_alerts for select
to authenticated
using (
  child_id = auth.uid()
  or exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = sos_alerts.child_id
      and link.linked_at is not null
      and link.linked_at <= sos_alerts.created_at
      and (
        link.status = 'active'
        or (
          link.status = 'revoked'
          and link.revoked_at is not null
          and sos_alerts.created_at <= link.revoked_at
        )
      )
  )
);

drop policy if exists "Active family views SOS live locations"
on public.sos_live_locations;
drop policy if exists "Family views SOS live locations"
on public.sos_live_locations;
create policy "Family views SOS live locations"
on public.sos_live_locations for select
to authenticated
using (
  child_id = auth.uid()
  or exists (
    select 1
    from public.sos_alerts alert
    join public.parent_child_links link
      on link.child_id = alert.child_id
    where alert.id = sos_live_locations.sos_id
      and link.parent_id = auth.uid()
      and link.linked_at is not null
      and link.linked_at <= alert.created_at
      and (
        link.status = 'active'
        or (
          link.status = 'revoked'
          and link.revoked_at is not null
          and alert.created_at <= link.revoked_at
        )
      )
  )
);

drop policy if exists "Active family views SOS events"
on public.sos_events;
drop policy if exists "Family views SOS events"
on public.sos_events;
create policy "Family views SOS events"
on public.sos_events for select
to authenticated
using (
  exists (
    select 1
    from public.sos_alerts alert
    where alert.id = sos_events.sos_id
      and (
        alert.child_id = auth.uid()
        or exists (
          select 1
          from public.parent_child_links link
          where link.parent_id = auth.uid()
            and link.child_id = alert.child_id
            and link.linked_at is not null
            and link.linked_at <= alert.created_at
            and (
              link.status = 'active'
              or (
                link.status = 'revoked'
                and link.revoked_at is not null
                and alert.created_at <= link.revoked_at
              )
            )
        )
      )
  )
);
