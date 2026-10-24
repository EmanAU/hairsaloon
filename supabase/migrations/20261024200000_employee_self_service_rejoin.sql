-- Keep self-service code/QR joining available after an employee leaves.
create or replace function private.request_join(invite_code uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare salon uuid; membership uuid;
begin
  if auth.uid() is null or not exists(select 1 from public.profiles where user_id=auth.uid()) then
    raise exception 'Create your profile first' using errcode='42501';
  end if;
  perform 1 from public.users where id=auth.uid() for update;
  if exists(select 1 from public.businesses where owner_id=auth.uid()) then
    raise exception 'Business owners cannot join a shop as an employee';
  end if;
  select b.id into salon from public.business_invites i join public.businesses b on b.id=i.business_id
    where i.code=invite_code and b.is_active;
  if salon is null then raise exception 'Invite unavailable'; end if;
  insert into public.business_employees(business_id,profile_id,requested_by)
    values(salon,auth.uid(),auth.uid())
    on conflict(business_id,profile_id) do update set join_status='pending',
      requested_by=excluded.requested_by, join_reviewed_at=null,join_reviewed_by=null,created_at=now()
    where business_employees.join_status in ('declined','left');
  select id into membership from public.business_employees where business_id=salon and profile_id=auth.uid();
  return membership;
end;
$$;


create or replace function private.review_join(employee uuid, accept boolean) returns void
language plpgsql security definer set search_path='' as $$
declare membership public.business_employees;
begin
  select * into membership from public.business_employees where id=employee for update;
  if auth.uid() is null or not coalesce(private.owns_business(membership.business_id),false) then
    raise exception 'Business owner access required' using errcode='42501';
  end if;
  if accept is null or membership.join_status<>'pending' then raise exception 'Request already handled'; end if;
  if not exists(select 1 from public.businesses where id=membership.business_id and is_active) then
    raise exception 'Business approval required';
  end if;
  update public.business_employees set join_status=case when accept then 'accepted' else 'declined' end,
    is_active=accept,join_reviewed_at=now(),join_reviewed_by=auth.uid() where id=employee;
end;
$$;

notify pgrst,'reload schema';
