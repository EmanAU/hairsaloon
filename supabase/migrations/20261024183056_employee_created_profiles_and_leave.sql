-- Owner-assisted employee onboarding. Auth identities are never fabricated.
alter table public.employee_invites
  add column local_employee_id uuid unique,
  add column employee_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(employee_data) = 'object' and octet_length(employee_data::text) <= 3000000);
alter table public.business_employees add column is_active boolean not null default true;
-- Preserve status switches already saved by owners in existing POS snapshots.
update public.business_employees e set is_active=(s.payload #>> array['employees',e.id::text,'isActive'])::boolean
from public.business_snapshots s where s.business_id=e.business_id
  and jsonb_typeof(s.payload #> array['employees',e.id::text,'isActive'])='boolean';
update public.business_employees set is_active=false where join_status<>'accepted';
update public.business_employees set is_manager=false,manager_pin_hash=null where not is_active;
alter table public.business_employees drop constraint business_employees_join_status_check;
alter table public.business_employees add constraint business_employees_join_status_check
  check (join_status in ('pending','accepted','declined','left'));
alter table public.business_employees add constraint business_employees_active_manager_check
  check (not is_manager or (is_active and join_status='accepted'));

create or replace function private.invite_matches_current_user(invite_cnic text, invite_email text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from auth.users u
    left join public.profiles p on p.user_id=u.id
    where u.id=(select auth.uid()) and u.email_confirmed_at is not null
      and lower(trim(u.email))=lower(trim(invite_email))
      and (p.cnic is null or p.cnic=invite_cnic)
  )
$$;

create function private.save_employee_record(business uuid, employee jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare local_id uuid := (employee->>'id')::uuid;
  employee_cnic text := regexp_replace(coalesce(employee->>'cnicNumber',''),'[^0-9]','','g');
  employee_email text := lower(trim(coalesce(employee->>'email','')));
  employee_phone text := trim(coalesce(employee->>'phoneNumber',''));
  born date := (employee->>'dateOfBirth')::date;
  started date := (employee->>'workStartedOn')::date;
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode='42501';
  end if;
  if not exists(select 1 from public.businesses where id=business and is_active) then
    raise exception 'Business approval required';
  end if;
  if local_id is null or length(trim(coalesce(employee->>'firstName','')))=0
    or employee_cnic !~ '^[0-9]{13}$' or employee_phone !~ '^\+?[0-9]{10,15}$'
    or employee_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
    or born is null or started is null or born>=current_date or started<born or started>current_date then
    raise exception 'Check employee name, Google email, CNIC, phone and dates';
  end if;
  if exists(select 1 from public.employee_invites where local_employee_id=local_id and business_id<>business) then
    raise exception 'Employee record belongs to a different business' using errcode='42501';
  end if;
  insert into public.employee_invites(business_id,cnic,phone,email,display_name,invited_by,local_employee_id,employee_data)
  values(business,employee_cnic,employee_phone,employee_email,
    trim(concat_ws(' ',employee->>'firstName',employee->>'lastName')),auth.uid(),local_id,employee)
  on conflict(business_id,cnic) do update set
    phone=excluded.phone,email=excluded.email,display_name=excluded.display_name,
    local_employee_id=coalesce(employee_invites.local_employee_id,excluded.local_employee_id),
    employee_data=excluded.employee_data;
end $$;
create function public.save_employee_record(business uuid, employee jsonb) returns void
language sql security invoker set search_path='' as $$ select private.save_employee_record(business,employee) $$;

create or replace function private.pending_invites_for_me()
returns table(invite_id uuid,business_id uuid,business_name text,owner_name text,cnic text,phone text,email text)
language sql stable security definer set search_path='' as $$
  select i.id,i.business_id,b.name,u.display_name,i.cnic,i.phone,i.email
  from public.employee_invites i join public.businesses b on b.id=i.business_id
  join public.users u on u.id=i.invited_by
  where i.status='pending' and b.is_active
    and private.invite_matches_current_user(i.cnic,i.email)
  order by i.created_at desc
$$;

create or replace function private.respond_to_employee_invite(invite uuid, accept boolean)
returns void language plpgsql security definer set search_path='' as $$
declare invitation public.employee_invites; membership uuid; existing_profile public.profiles;
begin
  if auth.uid() is null then raise exception 'Sign in required' using errcode='42501'; end if;
  -- Serialize role changes for this identity.
  perform 1 from public.users where id=auth.uid() for update;
  select * into invitation from public.employee_invites where id=invite for update;
  if invitation.id is null or not private.invite_matches_current_user(invitation.cnic,invitation.email) then
    raise exception 'Invite does not match your verified Google account' using errcode='42501';
  end if;
  if invitation.status='accepted' and exists(select 1 from public.business_employees
    where business_id=invitation.business_id and profile_id=auth.uid() and join_status='accepted') then return; end if;
  if invitation.status<>'pending' then raise exception 'Invite unavailable'; end if;
  if not accept then
    update public.employee_invites set status='declined',responded_at=now() where id=invite;
    return;
  end if;
  if not exists(select 1 from public.businesses where id=invitation.business_id and is_active) then
    raise exception 'Business approval required';
  end if;
  if exists(select 1 from public.businesses where owner_id=auth.uid()) then
    raise exception 'Business owners cannot join a shop as an employee';
  end if;
  select * into existing_profile from public.profiles where user_id=auth.uid();
  insert into public.profiles(user_id,phone,cnic,date_of_birth,work_started_on)
  values(auth.uid(),invitation.phone,invitation.cnic,
    (invitation.employee_data->>'dateOfBirth')::date,(invitation.employee_data->>'workStartedOn')::date)
  on conflict(user_id) do update set
    phone=case when profiles.phone='' then excluded.phone else profiles.phone end,
    cnic=coalesce(profiles.cnic,excluded.cnic),
    date_of_birth=coalesce(profiles.date_of_birth,excluded.date_of_birth),
    work_started_on=coalesce(profiles.work_started_on,excluded.work_started_on);
  if existing_profile.user_id is null and length(trim(invitation.display_name))>0 then
    update public.users set display_name=invitation.display_name where id=auth.uid();
  end if;
  insert into public.business_employees(id,business_id,profile_id,requested_by,join_status,join_reviewed_at,join_reviewed_by,is_active)
  values(coalesce(invitation.local_employee_id,gen_random_uuid()),invitation.business_id,auth.uid(),invitation.invited_by,
    'accepted',now(),invitation.invited_by,coalesce((invitation.employee_data->>'isActive')::boolean,true))
  on conflict(business_id,profile_id) do update set join_status='accepted',join_reviewed_at=now(),
    join_reviewed_by=invitation.invited_by,is_active=excluded.is_active
  returning id into membership;
  update public.employee_invites set status='accepted',responded_at=now() where id=invite;
end $$;

create function private.respond_to_employee_invite_profile(invite uuid, accept boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare data jsonb;
begin
  perform private.respond_to_employee_invite(invite,accept);
  if not accept then return '{}'::jsonb; end if;
  select employee_data into data from public.employee_invites where id=invite;
  return coalesce(data,'{}'::jsonb);
end $$;
create function public.respond_to_employee_invite_profile(invite uuid, accept boolean) returns jsonb
language sql security invoker set search_path='' as $$ select private.respond_to_employee_invite_profile(invite,accept) $$;

create function private.has_employment() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.business_employees where profile_id=auth.uid() and join_status='accepted')
$$;
alter policy businesses_create on public.businesses with check (
  owner_id=(select auth.uid()) and not is_active and not (select private.has_employment())
);

create function private.set_employee_active(employee uuid, active boolean) returns void
language plpgsql security definer set search_path='' as $$
declare member public.business_employees;
begin
 select * into member from public.business_employees where id=employee for update;
 if member.id is null or auth.uid() is null or not private.owns_business(member.business_id) then
   raise exception 'Business owner access required' using errcode='42501'; end if;
 if member.join_status<>'accepted' then raise exception 'Employee must accept a new invitation before rejoining'; end if;
 update public.business_employees set is_active=active,
   is_manager=case when active then is_manager else false end,
   manager_pin_hash=case when active then manager_pin_hash else null end where id=employee;
end $$;
create function public.set_employee_active(employee uuid, active boolean) returns void
language sql security invoker set search_path='' as $$ select private.set_employee_active(employee,active) $$;

create function private.leave_business(business uuid) returns void
language plpgsql security definer set search_path='' as $$
declare member public.business_employees;
begin
 if auth.uid() is null then raise exception 'Sign in required' using errcode='42501'; end if;
 perform 1 from public.users where id=auth.uid() for update;
 select * into member from public.business_employees where business_id=business and profile_id=auth.uid() for update;
 if member.id is null then raise exception 'You are not an employee of this business' using errcode='42501'; end if;
 if member.join_status='left' then return; end if;
 if member.join_status<>'accepted' then raise exception 'No accepted membership to leave'; end if;
 update public.employee_contracts set status='released',released_at=now(),released_by=auth.uid(),
   release_reason='Employee left the business' where employee_id=member.id and status='accepted';
 update public.business_employees set join_status='left',is_active=false,is_manager=false,manager_pin_hash=null where id=member.id;
 update public.employee_invites set employee_data=jsonb_set(employee_data,'{isActive}','false'::jsonb)
   where business_id=business and cnic=(select cnic from public.profiles where user_id=auth.uid());
end $$;
create function public.leave_business(business uuid) returns void
language sql security invoker set search_path='' as $$ select private.leave_business(business) $$;

-- The owner needs both the assignment flag and the provisional local ID.
drop function public.business_team(uuid);
drop function private.business_team(uuid);
create function private.business_team(business uuid)
returns table(membership_id uuid,display_name text,is_working boolean,join_status text,is_manager boolean,phone text,cnic text,is_active boolean,local_employee_id uuid)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.owns_business(business) then
  raise exception 'Business owner access required' using errcode='42501'; end if;
 return query select e.id,u.display_name,
   e.is_active and e.join_status='accepted' and exists(select 1 from public.employee_contracts c where c.employee_id=e.id and c.status='accepted' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now())),
   e.join_status,e.is_manager,coalesce(p.phone,''),coalesce(p.cnic,''),e.is_active,i.local_employee_id
 from public.business_employees e join public.users u on u.id=e.profile_id
 left join public.profiles p on p.user_id=e.profile_id
 left join public.employee_invites i on i.business_id=e.business_id and i.cnic=p.cnic
 where e.business_id=business order by e.created_at desc,e.id;
end $$;
create function public.business_team(business uuid)
returns table(membership_id uuid,display_name text,is_working boolean,join_status text,is_manager boolean,phone text,cnic text,is_active boolean,local_employee_id uuid)
language sql stable security invoker set search_path='' as $$ select * from private.business_team(business) $$;

revoke all on function private.save_employee_record(uuid,jsonb),private.respond_to_employee_invite_profile(uuid,boolean),private.has_employment(),private.set_employee_active(uuid,boolean),private.leave_business(uuid),private.business_team(uuid) from public,anon;
revoke all on function public.save_employee_record(uuid,jsonb),public.respond_to_employee_invite_profile(uuid,boolean),public.set_employee_active(uuid,boolean),public.leave_business(uuid),public.business_team(uuid) from public,anon;
grant execute on function private.save_employee_record(uuid,jsonb),private.respond_to_employee_invite_profile(uuid,boolean),private.has_employment(),private.set_employee_active(uuid,boolean),private.leave_business(uuid),private.business_team(uuid) to authenticated;
grant execute on function public.save_employee_record(uuid,jsonb),public.respond_to_employee_invite_profile(uuid,boolean),public.set_employee_active(uuid,boolean),public.leave_business(uuid),public.business_team(uuid) to authenticated;
grant execute on function private.business_team(uuid) to service_role;
notify pgrst,'reload schema';
