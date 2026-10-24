-- Store owner-created terms with the assisted employee record before an auth
-- identity exists. Materialize the contract atomically when that person joins.
create function private.validate_assisted_contract() returns trigger
language plpgsql set search_path='' as $$
declare terms jsonb := new.employee_data->'contract';
  contract_id uuid; starts timestamptz; ends timestamptz;
  salary numeric; commission numeric; kind text;
begin
  if terms is null or terms='null'::jsonb then return new; end if;
  if jsonb_typeof(terms)<>'object' then raise exception 'Invalid employee contract'; end if;
  contract_id := (terms->>'id')::uuid;
  starts := (terms->>'startsAt')::timestamptz;
  ends := (terms->>'endsAt')::timestamptz;
  salary := (terms->>'salary')::numeric;
  commission := (terms->>'commission')::numeric;
  kind := terms->>'kind';
  if contract_id is null or starts is null or not isfinite(starts)
    or (ends is not null and not isfinite(ends))
    or kind is null or kind not in ('permanent','daily','fixed')
    or salary is null or salary<0 or salary>9999999999.99
    or commission is null or commission<0 or commission>100
    or (kind='permanent' and ends is not null)
    or (kind<>'permanent' and ends is null)
    or ends<=starts or (kind='daily' and ends>starts+interval '24 hours')
    or length(coalesce(terms->>'terms',''))>20000 then
    raise exception 'Check employee contract dates, salary and commission';
  end if;
  return new;
end $$;
create trigger employee_invites_validate_contract
before insert or update of employee_data on public.employee_invites
for each row execute function private.validate_assisted_contract();
revoke all on function private.validate_assisted_contract() from public,anon,authenticated;

create or replace function private.respond_to_employee_invite_profile(invite uuid, accept boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare invitation public.employee_invites; membership uuid; saved_terms jsonb;
begin
  -- Existing verified-email/CNIC matching, owner restrictions and membership
  -- checks remain authoritative; no auth identities are fabricated here.
  perform private.respond_to_employee_invite(invite,accept);
  if not accept then return '{}'::jsonb; end if;
  select * into invitation from public.employee_invites where id=invite;
  select id into membership from public.business_employees
    where business_id=invitation.business_id and profile_id=auth.uid()
      and join_status='accepted';
  if membership is null then raise exception 'Employee membership required' using errcode='42501'; end if;
  saved_terms := invitation.employee_data->'contract';
  if saved_terms is not null and saved_terms<>'null'::jsonb then
    if exists(select 1 from public.employee_contracts
      where id=(saved_terms->>'id')::uuid and employee_id<>membership) then
      raise exception 'Contract belongs to another employee' using errcode='42501';
    end if;
    insert into public.employee_contracts(id,employee_id,profile_id,kind,starts_at,ends_at,
      salary,commission_percent,terms,status,accepted_at)
    values((saved_terms->>'id')::uuid,membership,auth.uid(),saved_terms->>'kind',
      (saved_terms->>'startsAt')::timestamptz,(saved_terms->>'endsAt')::timestamptz,
      (saved_terms->>'salary')::numeric,(saved_terms->>'commission')::numeric,
      coalesce(saved_terms->>'terms',''),'accepted',now())
    on conflict(id) do nothing;
  end if;
  return coalesce(invitation.employee_data,'{}'::jsonb);
end $$;
revoke all on function private.respond_to_employee_invite_profile(uuid,boolean) from public,anon;
grant execute on function private.respond_to_employee_invite_profile(uuid,boolean) to authenticated;
notify pgrst,'reload schema';
