-- Owner team sees contact fields for contract/details prefill.
-- Identity invites always require employee Yes/No (no silent auto-join).

drop function if exists public.business_team(uuid);
drop function if exists private.business_team(uuid);

create or replace function private.business_team(business uuid)
returns table(
  membership_id uuid,
  display_name text,
  is_working boolean,
  join_status text,
  is_manager boolean,
  phone text,
  cnic text
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  return query
  select
    e.id,
    u.display_name,
    exists(
      select 1 from public.employee_contracts c
      where c.employee_id = e.id and c.status = 'accepted'
        and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())
    ),
    e.join_status,
    e.is_manager,
    coalesce(p.phone, ''),
    coalesce(p.cnic, '')
  from public.business_employees e
  join public.users u on u.id = e.profile_id
  left join public.profiles p on p.user_id = e.profile_id
  where e.business_id = business
  order by e.created_at desc, e.id;
end;
$$;

create or replace function public.business_team(business uuid)
returns table(
  membership_id uuid,
  display_name text,
  is_working boolean,
  join_status text,
  is_manager boolean,
  phone text,
  cnic text
)
language sql stable security invoker set search_path = '' as $$
  select * from private.business_team(business);
$$;

create or replace function private.invite_employee_by_identity(
  business uuid,
  employee_cnic text,
  employee_phone text,
  employee_email text,
  employee_name text default ''
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  clean_cnic text := regexp_replace(coalesce(employee_cnic, ''), '[^0-9]', '', 'g');
  clean_phone text := trim(employee_phone);
  clean_email text := lower(trim(employee_email));
  existing_profile uuid;
  invite_id uuid;
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.businesses where id = business and is_active) then
    raise exception 'Business approval required';
  end if;
  if clean_cnic !~ '^[0-9]{13}$' then raise exception 'Enter a valid 13-digit CNIC'; end if;
  if clean_phone !~ '^\+?[0-9]{10,15}$' then raise exception 'Enter a valid phone number'; end if;
  if clean_email !~ '^[^@]+@[^@]+\.[^@]+$' then raise exception 'Enter a valid email'; end if;

  select p.user_id into existing_profile
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where p.cnic = clean_cnic and lower(coalesce(u.email, '')) = clean_email
  limit 1;

  if existing_profile is not null
     and exists (
       select 1 from public.business_employees e
       where e.business_id = business
         and e.profile_id = existing_profile
         and e.join_status = 'accepted'
     ) then
    raise exception 'This person is already on your team';
  end if;

  -- Always pending: employee must accept (whether or not they already have an account).
  insert into public.employee_invites(
    business_id, cnic, phone, email, display_name, invited_by, status
  )
  values (
    business, clean_cnic, clean_phone, clean_email,
    coalesce(nullif(trim(employee_name), ''), ''),
    auth.uid(), 'pending'
  )
  on conflict (business_id, cnic) do update
    set phone = excluded.phone,
        email = excluded.email,
        display_name = excluded.display_name,
        invited_by = excluded.invited_by,
        status = 'pending',
        responded_at = null,
        created_at = now()
  returning id into invite_id;
  return invite_id;
end;
$$;

grant execute on function public.business_team(uuid) to authenticated;
grant execute on function private.business_team(uuid) to service_role;
