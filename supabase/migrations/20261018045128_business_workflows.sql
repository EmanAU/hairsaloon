create function private.review_business(business uuid, active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Superadmin access required' using errcode = '42501';
  end if;
  if active is null then raise exception 'Activation status required'; end if;
  update public.businesses set is_active = active, reviewed_by = auth.uid(), reviewed_at = now()
  where id = business;
  if not found then raise exception 'Business not found'; end if;
end;
$$;

-- A code identifies a join request; it never grants contract or account access.
create function private.request_join(invite_code uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare business uuid; membership uuid;
begin
  if auth.uid() is null or not exists (select 1 from public.profiles where user_id = auth.uid()) then
    raise exception 'Create your profile first' using errcode = '42501';
  end if;
  select b.id into business from public.business_invites i
    join public.businesses b on b.id = i.business_id where i.code = invite_code and b.is_active;
  if business is null then raise exception 'Invite unavailable'; end if;
  insert into public.business_employees(business_id, profile_id, requested_by)
    values (business, auth.uid(), auth.uid())
    on conflict (business_id, profile_id) do nothing;
  select id into membership from public.business_employees
    where business_id = business and profile_id = auth.uid();
  return membership;
end;
$$;

create function private.invite_employee(business uuid, profile_code uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare employee_profile uuid; membership uuid;
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.businesses where id = business and is_active) then
    raise exception 'Business approval required';
  end if;
  select user_id into employee_profile from public.profiles where code = profile_code;
  if employee_profile is null then raise exception 'Profile not found'; end if;
  insert into public.business_employees(business_id, profile_id, requested_by)
    values (business, employee_profile, auth.uid()) on conflict (business_id, profile_id) do nothing;
  select id into membership from public.business_employees
    where business_id = business and profile_id = employee_profile;
  return membership;
end;
$$;

create function private.propose_contract(
  employee uuid, contract_kind text, starts timestamptz, ends timestamptz,
  basic_salary numeric, commission numeric, description text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare membership public.business_employees; contract uuid;
begin
  select * into membership from public.business_employees where id = employee;
  if auth.uid() is null or not coalesce(private.owns_business(membership.business_id), false) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.businesses where id = membership.business_id and is_active) then
    raise exception 'Business approval required';
  end if;
  if ends <= now() then raise exception 'Contract already ended'; end if;
  insert into public.employee_contracts(employee_id, profile_id, kind, starts_at, ends_at,
    salary, commission_percent, terms)
  values (employee, membership.profile_id, contract_kind, starts, ends, basic_salary, commission, description)
  returning id into contract;
  return contract;
end;
$$;

create function private.respond_to_contract(contract uuid, accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare agreement public.employee_contracts;
begin
  select * into agreement from public.employee_contracts where id = contract for update;
  if auth.uid() is null or agreement.profile_id is distinct from auth.uid() then
    raise exception 'Employee access required' using errcode = '42501';
  end if;
  if accept is null or agreement.status <> 'draft' then raise exception 'Invalid contract response'; end if;
  if accept and (agreement.ends_at <= now() or not exists (
    select 1 from public.business_employees e join public.businesses b on b.id = e.business_id
    where e.id = agreement.employee_id and b.is_active
  )) then raise exception 'Contract unavailable'; end if;
  update public.employee_contracts set status = case when accept then 'accepted' else 'declined' end,
    accepted_at = case when accept then now() else null end where id = contract;
end;
$$;

create function private.release_contract(contract uuid, reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare agreement public.employee_contracts; business uuid;
begin
  select * into agreement from public.employee_contracts where id = contract for update;
  select business_id into business from public.business_employees where id = agreement.employee_id;
  if auth.uid() is null or not (private.owns_business(business) or private.is_admin()) then
    raise exception 'Owner or superadmin access required' using errcode = '42501';
  end if;
  if agreement.status is distinct from 'accepted' or agreement.ends_at <= now() then
    raise exception 'Only an ongoing or scheduled contract can be released';
  end if;
  if reason is null or length(trim(reason)) = 0 then raise exception 'Release reason required'; end if;
  update public.employee_contracts set status = 'released', released_at = now(),
    released_by = auth.uid(), release_reason = trim(reason) where id = contract;
end;
$$;

-- Thin invoker wrappers expose only the explicitly authorized operations.
create function public.review_business(business uuid, active boolean) returns void
language sql security invoker set search_path = '' as $$ select private.review_business(business, active); $$;
create function public.request_join(invite_code uuid) returns uuid
language sql security invoker set search_path = '' as $$ select private.request_join(invite_code); $$;
create function public.invite_employee(business uuid, profile_code uuid) returns uuid
language sql security invoker set search_path = '' as $$ select private.invite_employee(business, profile_code); $$;
create function public.propose_contract(employee uuid, contract_kind text, starts timestamptz,
  ends timestamptz, basic_salary numeric, commission numeric, description text) returns uuid
language sql security invoker set search_path = '' as $$
  select private.propose_contract(employee, contract_kind, starts, ends, basic_salary, commission, description);
$$;
create function public.respond_to_contract(contract uuid, accept boolean) returns void
language sql security invoker set search_path = '' as $$ select private.respond_to_contract(contract, accept); $$;
create function public.release_contract(contract uuid, reason text) returns void
language sql security invoker set search_path = '' as $$ select private.release_contract(contract, reason); $$;

revoke all on function private.review_business(uuid, boolean), private.request_join(uuid),
  private.invite_employee(uuid, uuid), private.propose_contract(uuid, text, timestamptz, timestamptz, numeric, numeric, text),
  private.respond_to_contract(uuid, boolean), private.release_contract(uuid, text),
  public.review_business(uuid, boolean), public.request_join(uuid), public.invite_employee(uuid, uuid),
  public.propose_contract(uuid, text, timestamptz, timestamptz, numeric, numeric, text),
  public.respond_to_contract(uuid, boolean), public.release_contract(uuid, text) from public, anon;
grant execute on function private.review_business(uuid, boolean), private.request_join(uuid),
  private.invite_employee(uuid, uuid), private.propose_contract(uuid, text, timestamptz, timestamptz, numeric, numeric, text),
  private.respond_to_contract(uuid, boolean), private.release_contract(uuid, text),
  public.review_business(uuid, boolean), public.request_join(uuid), public.invite_employee(uuid, uuid),
  public.propose_contract(uuid, text, timestamptz, timestamptz, numeric, numeric, text),
  public.respond_to_contract(uuid, boolean), public.release_contract(uuid, text) to authenticated;

-- Reminders are read-time results, so expiry doesn't depend on a cron job.
create view public.contract_reminders with (security_invoker = true) as
  select id, employee_id, profile_id, ends_at from public.employee_contracts
  where status = 'accepted' and ends_at > now() and ends_at <= now() + interval '7 days';
revoke all on public.contract_reminders from anon, authenticated;
grant select on public.contract_reminders to authenticated;
