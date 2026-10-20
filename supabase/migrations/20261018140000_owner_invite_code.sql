-- Reliable owner lookup for the permanent employee joining code.
create or replace function private.owner_invite_code(business uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare invite uuid;
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  insert into public.business_invites(business_id)
  values (business)
  on conflict (business_id) do nothing;
  select code into invite from public.business_invites where business_id = business;
  if invite is null then
    raise exception 'Invite unavailable';
  end if;
  return invite;
end;
$$;

create or replace function public.owner_invite_code(business uuid) returns uuid
language sql security invoker set search_path = '' as $$
  select private.owner_invite_code(business);
$$;

revoke all on function private.owner_invite_code(uuid), public.owner_invite_code(uuid)
  from public, anon;
grant execute on function private.owner_invite_code(uuid), public.owner_invite_code(uuid)
  to authenticated;

-- Keep join requests clear when the salon is not active yet.
create or replace function private.request_join(invite_code uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare salon uuid; membership uuid; active boolean;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles where user_id = auth.uid()
  ) then
    raise exception 'Create your profile first' using errcode = '42501';
  end if;

  select b.id, b.is_active into salon, active
  from public.business_invites i
  join public.businesses b on b.id = i.business_id
  where i.code = invite_code;

  if salon is null then
    raise exception 'Invite unavailable';
  end if;
  if not coalesce(active, false) then
    raise exception 'Salon not approved yet';
  end if;

  insert into public.business_employees(business_id, profile_id, requested_by)
  values (salon, auth.uid(), auth.uid())
  on conflict (business_id, profile_id) do update
    set join_status = 'pending',
      requested_by = excluded.requested_by,
      join_reviewed_at = null,
      join_reviewed_by = null,
      created_at = now()
    where business_employees.join_status = 'declined';

  select id into membership
  from public.business_employees
  where business_id = salon and profile_id = auth.uid();
  return membership;
end;
$$;
