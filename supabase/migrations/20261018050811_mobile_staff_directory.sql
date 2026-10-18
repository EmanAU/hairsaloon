-- Share only staff display names. CNIC, DOB and contact details remain private.
create function private.business_staff(business uuid)
returns table (membership_id uuid, profile_id uuid, display_name text, is_working boolean)
language sql stable security definer set search_path = '' as $$
  select e.id, e.profile_id, u.display_name, exists (
    select 1 from public.employee_contracts c where c.employee_id = e.id
      and c.status = 'accepted' and c.starts_at <= now()
      and (c.ends_at is null or c.ends_at > now())
  ) as is_working
  from public.business_employees e join public.users u on u.id = e.profile_id
  where auth.uid() is not null and e.business_id = business and (
    private.owns_business(business) or private.is_admin() or (
      exists (select 1 from public.businesses b where b.id = business and b.is_active)
      and exists (select 1 from public.employee_contracts c where c.employee_id = e.id
        and c.status = 'accepted' and c.starts_at <= now()
        and (c.ends_at is null or c.ends_at > now()))
    )
  ) order by u.display_name, e.id;
$$;
create function public.business_staff(business uuid)
returns table (membership_id uuid, profile_id uuid, display_name text, is_working boolean)
language sql stable security invoker set search_path = '' as $$
  select * from private.business_staff(business);
$$;
revoke all on function private.business_staff(uuid), public.business_staff(uuid) from public, anon;
grant execute on function private.business_staff(uuid), public.business_staff(uuid) to authenticated;
