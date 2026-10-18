-- Accepted staff with a live contract can read the salon snapshot (for their own daily work view).
create or replace function private.is_salon_staff(business uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1
    from public.business_employees e
    join public.employee_contracts c on c.employee_id = e.id
    where e.business_id = business
      and e.profile_id = auth.uid()
      and e.join_status = 'accepted'
      and c.status = 'accepted'
      and c.starts_at <= now()
      and (c.ends_at is null or c.ends_at > now())
  );
$$;

revoke all on function private.is_salon_staff(uuid) from public, anon;
grant execute on function private.is_salon_staff(uuid) to authenticated;

drop policy if exists snapshots_read on public.business_snapshots;
create policy snapshots_read on public.business_snapshots for select to authenticated
  using (
    private.owns_business(business_id)
    or private.is_salon_staff(business_id)
    or (select private.is_admin())
  );
