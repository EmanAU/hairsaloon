alter table public.business_employees
  add column join_status text not null default 'pending'
    check(join_status in ('pending','accepted','declined')),
  add column join_reviewed_at timestamptz,
  add column join_reviewed_by uuid references public.users(id);

-- Preserve existing owner invitations and contract history.
update public.business_employees e set join_status='accepted'
where e.requested_by<>e.profile_id or exists (
  select 1 from public.employee_contracts c where c.employee_id=e.id
);

create or replace function private.request_join(invite_code uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare salon uuid; membership uuid;
begin
  if auth.uid() is null or not exists(select 1 from public.profiles where user_id=auth.uid()) then
    raise exception 'Create your profile first' using errcode='42501';
  end if;
  select b.id into salon from public.business_invites i join public.businesses b on b.id=i.business_id
    where i.code=invite_code and b.is_active;
  if salon is null then raise exception 'Invite unavailable'; end if;
  insert into public.business_employees(business_id,profile_id,requested_by)
    values(salon,auth.uid(),auth.uid())
    on conflict(business_id,profile_id) do update set join_status='pending',
      requested_by=excluded.requested_by, join_reviewed_at=null,join_reviewed_by=null,created_at=now()
    where business_employees.join_status='declined';
  select id into membership from public.business_employees where business_id=salon and profile_id=auth.uid();
  return membership;
end;
$$;

create or replace function private.invite_employee(business uuid, profile_code uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare employee_profile uuid; membership uuid;
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode='42501';
  end if;
  if not exists(select 1 from public.businesses where id=business and is_active) then
    raise exception 'Business approval required';
  end if;
  select user_id into employee_profile from public.profiles where code=profile_code;
  if employee_profile is null then raise exception 'Profile not found'; end if;
  insert into public.business_employees(business_id,profile_id,requested_by,join_status,join_reviewed_at,join_reviewed_by)
    values(business,employee_profile,auth.uid(),'accepted',now(),auth.uid())
    on conflict(business_id,profile_id) do update set join_status='accepted',
      join_reviewed_at=now(),join_reviewed_by=auth.uid()
    where business_employees.join_status<>'accepted';
  select id into membership from public.business_employees where business_id=business and profile_id=employee_profile;
  return membership;
end;
$$;

create function private.review_join(employee uuid, accept boolean) returns void
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
    join_reviewed_at=now(),join_reviewed_by=auth.uid() where id=employee;
end;
$$;
create function public.review_join(employee uuid, accept boolean) returns void
language sql security invoker set search_path='' as $$ select private.review_join(employee,accept); $$;

create function private.business_team(business uuid)
returns table(membership_id uuid,display_name text,is_working boolean,join_status text)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode='42501';
  end if;
  return query select e.id,u.display_name,exists(
    select 1 from public.employee_contracts c where c.employee_id=e.id and c.status='accepted'
      and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now())
  ),e.join_status from public.business_employees e join public.users u on u.id=e.profile_id
  where e.business_id=business order by e.created_at desc,e.id;
end;
$$;
create function public.business_team(business uuid)
returns table(membership_id uuid,display_name text,is_working boolean,join_status text)
language sql stable security invoker set search_path='' as $$ select * from private.business_team(business); $$;

-- Owner approval precedes every contract proposal and acceptance.
create function private.require_accepted_join() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if (tg_op='INSERT' or new.status='accepted') and not exists(
    select 1 from public.business_employees e where e.id=new.employee_id and e.join_status='accepted'
  ) then raise exception 'Accept the join request before creating a contract' using errcode='42501'; end if;
  return new;
end;
$$;
create trigger require_accepted_join before insert or update of status on public.employee_contracts
for each row execute function private.require_accepted_join();

revoke all on function private.review_join(uuid,boolean),public.review_join(uuid,boolean),
  private.business_team(uuid),public.business_team(uuid),private.require_accepted_join() from public,anon;
revoke all on function private.require_accepted_join() from authenticated;
grant execute on function private.review_join(uuid,boolean),public.review_join(uuid,boolean),
  private.business_team(uuid),public.business_team(uuid) to authenticated;
