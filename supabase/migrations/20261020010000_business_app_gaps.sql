-- Phase 2–6: contracts auto-accept, one shop per owner, employee pre-invites,
-- default rate list seeding, manager PIN for owner dashboard access.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Phase 3: one owner → one shop
-- ---------------------------------------------------------------------------
create unique index if not exists businesses_one_owner_uidx
  on public.businesses(owner_id);

-- ---------------------------------------------------------------------------
-- Phase 2: owner proposes → contract accepted immediately (employee notified)
-- ---------------------------------------------------------------------------
create or replace function private.propose_contract(
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
  if membership.join_status <> 'accepted' then
    raise exception 'Accept the join request before creating a contract' using errcode = '42501';
  end if;
  if ends is not null and ends <= now() then raise exception 'Contract already ended'; end if;
  insert into public.employee_contracts(
    employee_id, profile_id, kind, starts_at, ends_at,
    salary, commission_percent, terms, status, accepted_at
  )
  values (
    employee, membership.profile_id, contract_kind, starts, ends,
    basic_salary, commission, description, 'accepted', now()
  )
  returning id into contract;
  return contract;
end;
$$;

-- Employees no longer accept/decline; keep RPC but reject calls.
create or replace function private.respond_to_contract(contract uuid, accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'Contracts are set by the salon owner. Contact your owner for changes.'
    using errcode = '42501';
end;
$$;

-- ---------------------------------------------------------------------------
-- Phase 5: default services catalog + seed on business create
-- ---------------------------------------------------------------------------
create table if not exists public.default_services (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 160),
  category text not null,
  description text not null default '',
  price numeric(12,2) not null check (price >= 0),
  sort_order integer not null default 0
);

insert into public.default_services(name, category, description, price, sort_order)
select * from (values
  ('Simple Cutting', 'Hair Care & Styling', 'Standard haircut', 400::numeric, 1),
  ('Beard Trim', 'Men''s Grooming', 'Beard shaping and trim', 350::numeric, 2),
  ('Shave', 'Men''s Grooming', 'Clean shave', 300::numeric, 3),
  ('Basic Facial', 'Skincare & Facials', 'Basic facial treatment', 1500::numeric, 4),
  ('Cleanup', 'Skincare & Facials', 'Skin cleanup', 2200::numeric, 5),
  ('Keratin', 'Hair Treatments', 'Keratin treatment', 2500::numeric, 6),
  ('Hair Spa', 'Hair Treatments', 'Hair spa session', 1800::numeric, 7),
  ('Groom Package', 'Packages', 'Groom package', 2800::numeric, 8),
  ('Bridal Package', 'Packages', 'Bridal package', 8500::numeric, 9),
  ('Kids Hair Cut', 'Kids Services', 'Children''s haircut', 500::numeric, 10)
) as v(name, category, description, price, sort_order)
where not exists (select 1 from public.default_services limit 1);

create or replace function private.seed_business_services(business uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.services where business_id = business limit 1) then
    return;
  end if;
  insert into public.services(business_id, name, category, description, price, is_active)
  select business, d.name, d.category, d.description, d.price, true
  from public.default_services d
  order by d.sort_order, d.name;
end;
$$;

create or replace function private.seed_services_on_business() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.seed_business_services(new.id);
  return new;
end;
$$;

drop trigger if exists seed_services_after_business on public.businesses;
create trigger seed_services_after_business
  after insert on public.businesses
  for each row execute function private.seed_services_on_business();

-- Seed existing businesses that have an empty rate list.
do $$
declare b uuid;
begin
  for b in select id from public.businesses loop
    perform private.seed_business_services(b);
  end loop;
end $$;

create or replace function public.ensure_business_services(business uuid) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  perform private.seed_business_services(business);
end;
$$;

-- ---------------------------------------------------------------------------
-- Phase 4: pre-invite by CNIC + phone + email
-- ---------------------------------------------------------------------------
create table if not exists public.employee_invites (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  cnic text not null check (cnic ~ '^[0-9]{13}$'),
  phone text not null check (phone ~ '^\+?[0-9]{10,15}$'),
  email text not null check (length(trim(email)) between 3 and 254),
  display_name text not null default '',
  invited_by uuid not null references public.users(id),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (business_id, cnic) 
);

create index if not exists employee_invites_cnic_idx
  on public.employee_invites(cnic) where status = 'pending';
create index if not exists employee_invites_email_idx
  on public.employee_invites(lower(email)) where status = 'pending';

alter table public.employee_invites enable row level security;

create policy employee_invites_owner_all on public.employee_invites
  for all to authenticated
  using (private.owns_business(business_id))
  with check (private.owns_business(business_id));

create policy employee_invites_self_read on public.employee_invites
  for select to authenticated
  using (
    status = 'pending'
    and exists (
      select 1 from public.profiles p
      join auth.users u on u.id = p.user_id
      where p.user_id = auth.uid()
        and p.cnic = employee_invites.cnic
        and lower(coalesce(u.email, '')) = lower(employee_invites.email)
    )
  );

grant select, insert, update on public.employee_invites to authenticated;

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
  membership uuid;
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

  if existing_profile is not null then
    insert into public.business_employees(
      business_id, profile_id, requested_by, join_status, join_reviewed_at, join_reviewed_by
    )
    values (business, existing_profile, auth.uid(), 'accepted', now(), auth.uid())
    on conflict (business_id, profile_id) do update
      set join_status = 'accepted',
          join_reviewed_at = now(),
          join_reviewed_by = auth.uid()
      where business_employees.join_status <> 'accepted';
    select id into membership
    from public.business_employees
    where business_id = business and profile_id = existing_profile;
    insert into public.employee_invites(
      business_id, cnic, phone, email, display_name, invited_by, status, responded_at
    )
    values (
      business, clean_cnic, clean_phone, clean_email,
      coalesce(nullif(trim(employee_name), ''), ''),
      auth.uid(), 'accepted', now()
    )
    on conflict (business_id, cnic) do update
      set phone = excluded.phone,
          email = excluded.email,
          display_name = excluded.display_name,
          status = 'accepted',
          responded_at = now();
    return membership;
  end if;

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

create or replace function public.invite_employee_by_identity(
  business uuid,
  employee_cnic text,
  employee_phone text,
  employee_email text,
  employee_name text default ''
) returns uuid
language sql security invoker set search_path = '' as $$
  select private.invite_employee_by_identity(
    business, employee_cnic, employee_phone, employee_email, employee_name
  );
$$;

create or replace function private.pending_invites_for_me()
returns table (
  invite_id uuid,
  business_id uuid,
  business_name text,
  owner_name text,
  cnic text,
  phone text,
  email text
)
language plpgsql stable security definer set search_path = '' as $$
declare my_cnic text; my_email text;
begin
  if auth.uid() is null then return; end if;
  select p.cnic, lower(coalesce(u.email, '')) into my_cnic, my_email
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where p.user_id = auth.uid();
  if my_cnic is null or my_email = '' then return; end if;
  return query
  select i.id, i.business_id, b.name, ou.display_name, i.cnic, i.phone, i.email
  from public.employee_invites i
  join public.businesses b on b.id = i.business_id
  join public.users ou on ou.id = i.invited_by
  where i.status = 'pending'
    and i.cnic = my_cnic
    and lower(i.email) = my_email
    and b.is_active
  order by i.created_at desc;
end;
$$;

create or replace function public.pending_invites_for_me()
returns table (
  invite_id uuid,
  business_id uuid,
  business_name text,
  owner_name text,
  cnic text,
  phone text,
  email text
)
language sql stable security invoker set search_path = '' as $$
  select * from private.pending_invites_for_me();
$$;

create or replace function private.respond_to_employee_invite(invite uuid, accept boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare row public.employee_invites; my_cnic text; my_email text;
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  select * into row from public.employee_invites where id = invite for update;
  if row.id is null or row.status <> 'pending' then
    raise exception 'Invite unavailable';
  end if;
  select p.cnic, lower(coalesce(u.email, '')) into my_cnic, my_email
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where p.user_id = auth.uid();
  if my_cnic is distinct from row.cnic or my_email is distinct from lower(row.email) then
    raise exception 'Invite does not match your profile' using errcode = '42501';
  end if;
  if accept then
    insert into public.business_employees(
      business_id, profile_id, requested_by, join_status, join_reviewed_at, join_reviewed_by
    )
    values (row.business_id, auth.uid(), row.invited_by, 'accepted', now(), row.invited_by)
    on conflict (business_id, profile_id) do update
      set join_status = 'accepted',
          join_reviewed_at = now(),
          join_reviewed_by = row.invited_by;
    update public.employee_invites
      set status = 'accepted', responded_at = now()
      where id = invite;
  else
    update public.employee_invites
      set status = 'declined', responded_at = now()
      where id = invite;
  end if;
end;
$$;

create or replace function public.respond_to_employee_invite(invite uuid, accept boolean)
returns void
language sql security invoker set search_path = '' as $$
  select private.respond_to_employee_invite(invite, accept);
$$;

-- ---------------------------------------------------------------------------
-- Phase 6: manager + PIN
-- ---------------------------------------------------------------------------
alter table public.business_employees
  add column if not exists is_manager boolean not null default false,
  add column if not exists manager_pin_hash text;

-- At most one manager per business.
create unique index if not exists business_employees_one_manager_uidx
  on public.business_employees(business_id)
  where is_manager;

create or replace function private.set_employee_manager(
  employee uuid,
  make_manager boolean,
  pin text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare membership public.business_employees;
begin
  select * into membership from public.business_employees where id = employee for update;
  if auth.uid() is null or not coalesce(private.owns_business(membership.business_id), false) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  if membership.join_status <> 'accepted' then
    raise exception 'Only accepted employees can be managers';
  end if;
  if make_manager then
    if pin is null or pin !~ '^[0-9]{4}$' then
      raise exception 'Enter a 4-digit manager PIN';
    end if;
    update public.business_employees
      set is_manager = false, manager_pin_hash = null
      where business_id = membership.business_id and is_manager and id <> employee;
    update public.business_employees
      set is_manager = true,
          manager_pin_hash = extensions.crypt(pin, extensions.gen_salt('bf'))
      where id = employee;
  else
    update public.business_employees
      set is_manager = false, manager_pin_hash = null
      where id = employee;
  end if;
end;
$$;

create or replace function public.set_employee_manager(
  employee uuid,
  make_manager boolean,
  pin text default null
) returns void
language sql security invoker set search_path = '' as $$
  select private.set_employee_manager(employee, make_manager, pin);
$$;

create or replace function private.verify_manager_pin(business uuid, pin text)
returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare hash text;
begin
  if auth.uid() is null or pin is null or pin !~ '^[0-9]{4}$' then
    return false;
  end if;
  select e.manager_pin_hash into hash
  from public.business_employees e
  where e.business_id = business
    and e.profile_id = auth.uid()
    and e.is_manager
    and e.join_status = 'accepted';
  if hash is null then return false; end if;
  return extensions.crypt(pin, hash) = hash;
end;
$$;

create or replace function public.verify_manager_pin(business uuid, pin text)
returns boolean
language sql stable security invoker set search_path = '' as $$
  select private.verify_manager_pin(business, pin);
$$;

-- Expose manager flag on team listing.
-- OUT row type changed (added is_manager); REPLACE cannot alter it — drop first.
drop function if exists public.business_team(uuid);
drop function if exists private.business_team(uuid);

create or replace function private.business_team(business uuid)
returns table(
  membership_id uuid,
  display_name text,
  is_working boolean,
  join_status text,
  is_manager boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  return query select e.id, u.display_name, exists(
    select 1 from public.employee_contracts c
    where c.employee_id = e.id and c.status = 'accepted'
      and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())
  ), e.join_status, e.is_manager
  from public.business_employees e
  join public.users u on u.id = e.profile_id
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
  is_manager boolean
)
language sql stable security invoker set search_path = '' as $$
  select * from private.business_team(business);
$$;

create or replace function private.my_manager_businesses()
returns table(business_id uuid, business_name text, membership_id uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  return query
  select b.id, b.name, e.id
  from public.business_employees e
  join public.businesses b on b.id = e.business_id
  where e.profile_id = auth.uid()
    and e.is_manager
    and e.join_status = 'accepted'
    and b.is_active
  order by b.name;
end;
$$;

create or replace function public.my_manager_businesses()
returns table(business_id uuid, business_name text, membership_id uuid)
language sql stable security invoker set search_path = '' as $$
  select * from private.my_manager_businesses();
$$;

revoke all on function
  private.seed_business_services(uuid),
  private.seed_services_on_business(),
  public.ensure_business_services(uuid),
  private.invite_employee_by_identity(uuid, text, text, text, text),
  public.invite_employee_by_identity(uuid, text, text, text, text),
  private.pending_invites_for_me(),
  public.pending_invites_for_me(),
  private.respond_to_employee_invite(uuid, boolean),
  public.respond_to_employee_invite(uuid, boolean),
  private.set_employee_manager(uuid, boolean, text),
  public.set_employee_manager(uuid, boolean, text),
  private.verify_manager_pin(uuid, text),
  public.verify_manager_pin(uuid, text),
  private.my_manager_businesses(),
  public.my_manager_businesses()
from public, anon;

grant execute on function
  public.ensure_business_services(uuid),
  private.invite_employee_by_identity(uuid, text, text, text, text),
  public.invite_employee_by_identity(uuid, text, text, text, text),
  private.pending_invites_for_me(),
  public.pending_invites_for_me(),
  private.respond_to_employee_invite(uuid, boolean),
  public.respond_to_employee_invite(uuid, boolean),
  private.set_employee_manager(uuid, boolean, text),
  public.set_employee_manager(uuid, boolean, text),
  private.verify_manager_pin(uuid, text),
  public.verify_manager_pin(uuid, text),
  private.my_manager_businesses(),
  public.my_manager_businesses(),
  public.business_team(uuid)
to authenticated;

grant select on public.default_services to authenticated;

-- Managers with an accepted membership can use owner salon tools (PIN gates UI).
create or replace function private.owns_business(business uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    exists (
      select 1 from public.businesses
      where id = business and owner_id = auth.uid()
    )
    or exists (
      select 1 from public.business_employees e
      where e.business_id = business
        and e.profile_id = auth.uid()
        and e.is_manager
        and e.join_status = 'accepted'
    )
  );
$$;
