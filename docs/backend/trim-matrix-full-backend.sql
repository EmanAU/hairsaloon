-- TrimMatrix / complete backend bootstrap
-- Generated: 2026-10-25
-- Target: NEW Supabase PostgreSQL 17 project, run once as postgres in SQL Editor.
-- Includes 28 ordered application migrations, default catalogs, private
-- functions, RPCs, triggers, indexes, RLS, grants and Storage bucket policies.
-- Supabase must already provide auth.users, auth.uid(), storage.objects,
-- storage.buckets and the anon/authenticated/service_role roles.
-- This is NOT a generic standalone PostgreSQL dump or a user-data backup.
-- No existing application data is dropped; existing application schema is rejected.
-- Admin identity must be granted explicitly to a real authenticated user later.
-- OAuth providers, redirect URLs, secrets and actual image files are configured
-- outside SQL. CLI migration-history entries are not created by this bootstrap.

begin;

do $bootstrap$
begin
  if to_regclass('auth.users') is null or to_regclass('storage.objects') is null then
    raise exception 'Run this script inside a Supabase project with Auth and Storage enabled.';
  end if;
  if to_regclass('public.users') is not null or to_regclass('public.businesses') is not null then
    raise exception 'Application schema already exists. Use incremental migrations instead of this fresh-project bootstrap.';
  end if;
end
$bootstrap$;


-- ============================================================================
-- 20261018045119_core_tables.sql
-- ============================================================================

create schema if not exists extensions;
create extension if not exists btree_gist with schema extensions;
create schema if not exists private;
revoke all on schema private from public;

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 120),
  role text not null default 'user' check (role in ('user', 'superadmin')),
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references public.users(id),
  code uuid not null default gen_random_uuid() unique,
  cnic text unique check (cnic ~ '^[0-9]{13}$'),
  date_of_birth date,
  phone text not null check (phone ~ '^\+?[0-9]{10,15}$'),
  photo_path text,
  created_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id),
  name text not null check (length(trim(name)) between 1 and 160),
  phone text not null check (phone ~ '^\+?[0-9]{10,15}$'),
  business_type text not null,
  city text not null,
  area text not null,
  address text not null,
  logo_path text,
  is_active boolean not null default false,
  reviewed_by uuid references public.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index businesses_owner_idx on public.businesses(owner_id);

-- Invite codes are separate from the customer-visible salon information.
create table public.business_invites (
  business_id uuid primary key references public.businesses(id),
  code uuid not null default gen_random_uuid() unique
);

create table public.business_employees (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  profile_id uuid not null references public.profiles(user_id),
  requested_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  unique (business_id, profile_id),
  unique (id, profile_id)
);
create index business_employees_profile_idx on public.business_employees(profile_id);

create table public.employee_contracts (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null,
  profile_id uuid not null,
  kind text not null check (kind in ('daily', 'fixed', 'permanent')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  salary numeric(12,2) not null default 0 check (salary >= 0),
  commission_percent numeric(5,2) not null default 0 check (commission_percent between 0 and 100),
  terms text not null default '',
  status text not null default 'draft' check (status in ('draft', 'accepted', 'declined', 'released')),
  accepted_at timestamptz,
  released_at timestamptz,
  released_by uuid references public.users(id),
  release_reason text,
  created_at timestamptz not null default now(),
  foreign key (employee_id, profile_id) references public.business_employees(id, profile_id),
  check (ends_at is null or ends_at > starts_at),
  check ((kind = 'permanent' and ends_at is null) or (kind <> 'permanent' and ends_at is not null)),
  check (kind <> 'daily' or ends_at <= starts_at + interval '24 hours'),
  check ((status in ('accepted', 'released')) = (accepted_at is not null)),
  check ((status = 'released') = (released_at is not null)),
  check (status <> 'released' or (released_by is not null and length(trim(release_reason)) > 0)),
  -- Range constraints also serialize competing accept requests in PostgreSQL.
  exclude using gist (
    profile_id with =,
    tstzrange(starts_at, case when ends_at is null and released_at is null then null
      else greatest(starts_at, least(ends_at, released_at)) end, '[)') with &&
  ) where (status in ('accepted', 'released'))
);
create index employee_contracts_employee_idx on public.employee_contracts(employee_id);
create index employee_contracts_expiry_idx on public.employee_contracts(ends_at) where status = 'accepted';

create table public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  name text not null check (length(trim(name)) between 1 and 160),
  category text not null,
  subcategory text not null default '',
  gender text not null default '',
  age_group text not null default '',
  description text not null default '',
  price numeric(12,2) not null check (price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index services_business_idx on public.services(business_id);

create table public.service_media (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(id) on delete cascade,
  kind text not null check (kind in ('photo', 'video', 'before', 'after')),
  storage_path text not null,
  position integer not null default 0 check (position >= 0)
);
create index service_media_service_idx on public.service_media(service_id);

-- ============================================================================
-- 20261018045122_access_policies.sql
-- ============================================================================

-- Privileged lookups stay outside exposed schemas. No JWT metadata determines roles.
create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.users where id = auth.uid() and role = 'superadmin'
  );
$$;

create function private.owns_business(business uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.businesses where id = business and owner_id = auth.uid()
  );
$$;

create function private.can_read_employee(employee uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.business_employees e
    where e.id = employee and (e.profile_id = auth.uid()
      or private.owns_business(e.business_id) or private.is_admin())
  );
$$;

revoke all on function private.is_admin(), private.owns_business(uuid), private.can_read_employee(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_admin(), private.owns_business(uuid), private.can_read_employee(uuid) to authenticated;

alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_invites enable row level security;
alter table public.business_employees enable row level security;
alter table public.employee_contracts enable row level security;
alter table public.services enable row level security;
alter table public.service_media enable row level security;

revoke all on public.users, public.profiles, public.businesses, public.business_invites,
  public.business_employees, public.employee_contracts, public.services, public.service_media
  from anon, authenticated;
grant select on public.users, public.profiles, public.businesses, public.business_invites,
  public.business_employees, public.employee_contracts, public.services, public.service_media to authenticated;

grant insert (id, display_name), update (display_name) on public.users to authenticated;
create policy users_read on public.users for select to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));
create policy users_create on public.users for insert to authenticated
  with check (id = (select auth.uid()) and role = 'user');
create policy users_edit on public.users for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

grant insert (user_id, cnic, date_of_birth, phone, photo_path),
  update (cnic, date_of_birth, phone, photo_path) on public.profiles to authenticated;
create policy profiles_read on public.profiles for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy profiles_create on public.profiles for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy profiles_edit on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

grant insert (owner_id, name, phone, business_type, city, area, address, logo_path),
  update (name, phone, business_type, city, area, address, logo_path) on public.businesses to authenticated;
create policy businesses_read on public.businesses for select to authenticated
  using (is_active or owner_id = (select auth.uid()) or (select private.is_admin()));
create policy businesses_create on public.businesses for insert to authenticated
  with check (owner_id = (select auth.uid()) and not is_active);
create policy businesses_edit on public.businesses for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

grant insert (business_id) on public.business_invites to authenticated;
create policy invites_read on public.business_invites for select to authenticated
  using (private.owns_business(business_id) or (select private.is_admin()));
create policy invites_create on public.business_invites for insert to authenticated
  with check (private.owns_business(business_id));

create policy employees_read on public.business_employees for select to authenticated
  using (private.can_read_employee(id));
create policy contracts_read on public.employee_contracts for select to authenticated
  using (private.can_read_employee(employee_id));

grant insert (business_id, name, category, subcategory, gender, age_group, description, price, is_active),
  update (name, category, subcategory, gender, age_group, description, price, is_active), delete on public.services to authenticated;
create policy services_read on public.services for select to authenticated
  using (private.owns_business(business_id) or (select private.is_admin()) or
    (is_active and exists (select 1 from public.businesses b where b.id = business_id and b.is_active)));
create policy services_create on public.services for insert to authenticated
  with check (private.owns_business(business_id));
create policy services_edit on public.services for update to authenticated
  using (private.owns_business(business_id)) with check (private.owns_business(business_id));
create policy services_delete on public.services for delete to authenticated
  using (private.owns_business(business_id));

grant insert (service_id, kind, storage_path, position), update (kind, storage_path, position), delete on public.service_media to authenticated;
create policy media_read on public.service_media for select to authenticated
  using (exists (select 1 from public.services s where s.id = service_id));
create policy media_create on public.service_media for insert to authenticated
  with check (exists (select 1 from public.services s where s.id = service_id and private.owns_business(s.business_id)));
create policy media_edit on public.service_media for update to authenticated
  using (exists (select 1 from public.services s where s.id = service_id and private.owns_business(s.business_id)))
  with check (exists (select 1 from public.services s where s.id = service_id and private.owns_business(s.business_id)));
create policy media_delete on public.service_media for delete to authenticated
  using (exists (select 1 from public.services s where s.id = service_id and private.owns_business(s.business_id)));

-- ============================================================================
-- 20261018045128_business_workflows.sql
-- ============================================================================

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

-- ============================================================================
-- 20261018050811_mobile_staff_directory.sql
-- ============================================================================

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

-- ============================================================================
-- 20261018052659_media_reviews_sync.sql
-- ============================================================================

-- Public discovery exposes only the active employment and display name.
create function private.resolve_barber(employee uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select e.business_id from public.business_employees e
  join public.businesses b on b.id=e.business_id and b.is_active
  where auth.uid() is not null and e.id=employee and exists (
    select 1 from public.employee_contracts c where c.employee_id=e.id
    and c.status='accepted' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now()));
$$;
create function public.resolve_barber(employee uuid) returns uuid
language sql stable security invoker set search_path = '' as $$ select private.resolve_barber(employee); $$;
revoke all on function private.resolve_barber(uuid), public.resolve_barber(uuid) from public,anon;
grant execute on function private.resolve_barber(uuid), public.resolve_barber(uuid) to authenticated;

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  employee_id uuid references public.business_employees(id),
  author_id uuid not null default auth.uid() references public.users(id),
  rating smallint not null check (rating between 1 and 5),
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  unique nulls not distinct (business_id,employee_id,author_id)
);
create index reviews_author_idx on public.reviews(author_id);
create index reviews_employee_idx on public.reviews(employee_id);
alter table public.reviews enable row level security;
revoke all on public.reviews from anon,authenticated;
grant select,delete on public.reviews to authenticated;
grant insert(business_id,employee_id,rating,body),update(rating,body) on public.reviews to authenticated;
create policy reviews_read on public.reviews for select to authenticated using (
  author_id=(select auth.uid()) or (select private.is_admin()) or
  exists(select 1 from public.businesses b where b.id=business_id and b.is_active));
create policy reviews_create on public.reviews for insert to authenticated with check (author_id=(select auth.uid()));
create policy reviews_edit on public.reviews for update to authenticated
  using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
create policy reviews_delete on public.reviews for delete to authenticated
  using(author_id=(select auth.uid()) or (select private.is_admin()));
create function private.validate_review() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or new.author_id<>auth.uid() or not exists(
    select 1 from public.businesses b where b.id=new.business_id and b.is_active and b.owner_id<>auth.uid()
  ) or exists(select 1 from public.business_employees e where e.business_id=new.business_id and e.profile_id=auth.uid()) then
    raise exception 'You cannot review your own salon or an inactive salon' using errcode='42501';
  end if;
  if new.employee_id is not null and private.resolve_barber(new.employee_id) is distinct from new.business_id then
    raise exception 'Barber is not currently working at this salon' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function private.validate_review() from public,anon,authenticated;
create trigger validate_review before insert or update on public.reviews for each row execute function private.validate_review();

-- Private buckets: signed URLs remain subject to the same publication rules as services.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('service-media','service-media',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']),
 ('profile-photos','profile-photos',false,5242880,array['image/jpeg','image/png','image/webp']);
create function private.owns_media_path(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.services s
 join public.businesses b on b.id=s.business_id where b.owner_id=auth.uid()
 and split_part(path,'/',1)=b.id::text and split_part(path,'/',2)=s.id::text);
$$;
revoke all on function private.owns_media_path(text) from public,anon;
grant execute on function private.owns_media_path(text) to authenticated;
create policy service_upload on storage.objects for insert to authenticated
 with check(bucket_id='service-media' and private.owns_media_path(name));
create policy service_remove on storage.objects for delete to authenticated
 using(bucket_id='service-media' and private.owns_media_path(name));
create policy service_download on storage.objects for select to authenticated using(
 bucket_id='service-media' and (private.owns_media_path(name) or exists(
 select 1 from public.service_media m where m.storage_path=name)));
create policy profile_upload on storage.objects for insert to authenticated
 with check(bucket_id='profile-photos' and split_part(name,'/',1)=(select auth.uid())::text);
create policy profile_remove on storage.objects for delete to authenticated
 using(bucket_id='profile-photos' and split_part(name,'/',1)=(select auth.uid())::text);
create policy profile_download on storage.objects for select to authenticated
 using(bucket_id='profile-photos' and (split_part(name,'/',1)=(select auth.uid())::text or (select private.is_admin())));
-- Prevent an owner publishing another salon's storage object through their media row.
create function private.validate_media_path() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from public.services s where s.id=new.service_id
 and split_part(new.storage_path,'/',1)=s.business_id::text
 and split_part(new.storage_path,'/',2)=s.id::text) then
 raise exception 'Media path does not match service' using errcode='23514'; end if;
 return new;
end;
$$;
revoke all on function private.validate_media_path() from public,anon,authenticated;
create trigger validate_media_path before insert or update on public.service_media for each row execute function private.validate_media_path();

-- A complete POS snapshot is updated atomically. Competing devices must resolve
-- a version conflict; retries of the same operation never duplicate a write.
create table public.business_snapshots (
 business_id uuid primary key references public.businesses(id),
 revision bigint not null default 1,
 operation_id uuid not null,
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=20971520),
 updated_at timestamptz not null default now()
);
alter table public.business_snapshots enable row level security;
revoke all on public.business_snapshots from anon,authenticated;
grant select on public.business_snapshots to authenticated;
create policy snapshots_read on public.business_snapshots for select to authenticated
 using(private.owns_business(business_id) or (select private.is_admin()));
create function private.sync_business(business uuid, expected_revision bigint, operation uuid, data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare current_row public.business_snapshots;
begin
 if not private.owns_business(business) then raise exception 'Owner required' using errcode='42501'; end if;
 -- Lock the parent even before the first snapshot exists.
 perform 1 from public.businesses where id=business for update;
 select * into current_row from public.business_snapshots where business_id=business;
 if current_row.operation_id=operation then
   if current_row.payload<>data then raise exception 'Operation reused with different data' using errcode='22023'; end if;
   return jsonb_build_object('conflict',false,'revision',current_row.revision);
 end if;
 if coalesce(current_row.revision,0)<>expected_revision then
   return jsonb_build_object('conflict',true,'revision',current_row.revision);
 end if;
 insert into public.business_snapshots(business_id,revision,operation_id,payload)
 values(business,expected_revision+1,operation,data)
 on conflict(business_id) do update set revision=excluded.revision,operation_id=excluded.operation_id,payload=excluded.payload,updated_at=now();
 return jsonb_build_object('conflict',false,'revision',expected_revision+1);
end;
$$;
create function public.sync_business(business uuid, expected_revision bigint, operation uuid, data jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select private.sync_business(business,expected_revision,operation,data); $$;
revoke all on function private.sync_business(uuid,bigint,uuid,jsonb),public.sync_business(uuid,bigint,uuid,jsonb) from public,anon;
grant execute on function private.sync_business(uuid,bigint,uuid,jsonb),public.sync_business(uuid,bigint,uuid,jsonb) to authenticated;

alter table public.profiles add constraint profile_photo_owner check(photo_path is null or split_part(photo_path,'/',1)=user_id::text);
create function private.barber_photo(employee uuid) returns text
language sql stable security definer set search_path='' as $$
 select p.photo_path from public.profiles p join public.business_employees e on e.profile_id=p.user_id
 where e.id=employee and private.resolve_barber(employee) is not null;
$$;
create function public.barber_photo(employee uuid) returns text
language sql stable security invoker set search_path='' as $$ select private.barber_photo(employee); $$;
create function private.public_profile_photo(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles p
 join public.business_employees e on e.profile_id=p.user_id
 where p.photo_path=path and private.resolve_barber(e.id) is not null);
$$;
revoke all on function private.barber_photo(uuid),public.barber_photo(uuid),private.public_profile_photo(text) from public,anon;
grant execute on function private.barber_photo(uuid),public.barber_photo(uuid),private.public_profile_photo(text) to authenticated;
create policy public_barber_photo on storage.objects for select to authenticated
 using(bucket_id='profile-photos' and private.public_profile_photo(name));

alter table public.service_media add column pair_id uuid;
alter table public.service_media add constraint media_pair_kind check(pair_id is null or kind in ('before','after'));
create unique index service_media_pair_idx on public.service_media(service_id,pair_id,kind) where pair_id is not null;
grant insert(pair_id) on public.service_media to authenticated;

-- ============================================================================
-- 20261018121502_personal_profile_onboarding.sql
-- ============================================================================

-- Store the starting date, rather than an experience total that becomes stale.
alter table public.profiles add column work_started_on date;
alter table public.profiles add constraint profile_work_dates
  check (work_started_on is null or (
    work_started_on <= current_date and
    (date_of_birth is null or work_started_on >= date_of_birth)
  ));
grant insert (work_started_on), update (work_started_on) on public.profiles to authenticated;

-- Reuse the private profile bucket and its existing ownership policies.
update storage.buckets set file_size_limit = 2097152 where id = 'profile-photos';

-- ============================================================================
-- 20261018124359_business_photos.sql
-- ============================================================================

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('business-photos','business-photos',false,2097152,
  array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

alter table public.businesses add constraint business_photo_path
  check (logo_path is null or split_part(logo_path,'/',1)=id::text);

create policy business_photo_upload on storage.objects for insert to authenticated
with check (bucket_id='business-photos' and exists (
  select 1 from public.businesses b where b.id::text=split_part(storage.objects.name,'/',1)
  and b.owner_id=(select auth.uid())
));
create policy business_photo_remove on storage.objects for delete to authenticated
using (bucket_id='business-photos' and exists (
  select 1 from public.businesses b where b.id::text=split_part(storage.objects.name,'/',1)
  and b.owner_id=(select auth.uid())
));
create policy business_photo_read on storage.objects for select to authenticated
using (bucket_id='business-photos' and exists (
  select 1 from public.businesses b where b.id::text=split_part(storage.objects.name,'/',1)
  and (b.is_active or b.owner_id=(select auth.uid()) or (select private.is_admin()))
));

-- ============================================================================
-- 20261018125222_business_registration_code.sql
-- ============================================================================

-- Assign a permanent employee joining code in the registration transaction.
create function private.create_business_code() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.business_invites(business_id) values (new.id);
  return new;
end;
$$;
revoke all on function private.create_business_code() from public,anon,authenticated;
create trigger create_business_code after insert on public.businesses
for each row execute function private.create_business_code();

-- Preserve any codes already shared by existing businesses.
insert into public.business_invites(business_id)
select id from public.businesses
on conflict (business_id) do nothing;

-- ============================================================================
-- 20261018125823_employee_join_approval.sql
-- ============================================================================

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

-- ============================================================================
-- 20261018140000_owner_invite_code.sql
-- ============================================================================

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

-- ============================================================================
-- 20261018150000_employee_snapshot_read.sql
-- ============================================================================

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

-- ============================================================================
-- 20261020010000_business_app_gaps.sql
-- ============================================================================

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

-- ============================================================================
-- 20261020020000_service_content_json.sql
-- ============================================================================

-- Rich customer-view body for services (Flutter Quill Delta JSON).
alter table public.services
  add column if not exists content_json jsonb not null default '[]'::jsonb;

-- ============================================================================
-- 20261020030000_business_defaults.sql
-- ============================================================================

-- Business defaults: tax 17%, currency PKR, expense types, payment accounts,
-- and full rate-list catalog. Seed once per business; owner CRUD stays local
-- to that business (never overwrite non-empty lists).

-- ---------------------------------------------------------------------------
-- Tax + currency on businesses
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column if not exists tax_rate numeric(5,2) not null default 17
    check (tax_rate >= 0 and tax_rate <= 100);

alter table public.businesses
  add column if not exists currency_code text not null default 'PKR'
    check (currency_code ~ '^[A-Z]{3}$');

alter table public.businesses
  add column if not exists expense_types text[] not null default '{}';

alter table public.businesses
  add column if not exists payment_accounts text[] not null default '{}';

grant update (
  name, phone, business_type, city, area, address, logo_path,
  tax_rate, currency_code, expense_types, payment_accounts
) on public.businesses to authenticated;

-- ---------------------------------------------------------------------------
-- Global default catalogs
-- ---------------------------------------------------------------------------
create table if not exists public.default_expense_types (
  name text primary key check (length(trim(name)) between 1 and 80),
  sort_order integer not null default 0
);

create table if not exists public.default_payment_accounts (
  label text primary key check (length(trim(label)) between 1 and 120),
  sort_order integer not null default 0
);

insert into public.default_expense_types(name, sort_order)
select * from (values
  ('Utilities', 1),
  ('Supplies', 2),
  ('Maintenance', 3),
  ('Tea/Coffee', 4),
  ('Rent', 5),
  ('Salary Advance', 6),
  ('Marketing', 7),
  ('Transport', 8),
  ('Cleaning', 9),
  ('Miscellaneous', 10)
) as v(name, sort_order)
on conflict (name) do update set sort_order = excluded.sort_order;

insert into public.default_payment_accounts(label, sort_order)
select * from (values
  ('Cash — Counter', 1),
  ('Card — POS', 2),
  ('Online — Bank transfer', 3)
) as v(label, sort_order)
on conflict (label) do update set sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Full rate-list catalog (categories + subcategories + prices)
-- ---------------------------------------------------------------------------
alter table public.default_services
  add column if not exists subcategory text not null default '';
alter table public.default_services
  add column if not exists gender text not null default '';
alter table public.default_services
  add column if not exists age_group text not null default '';

-- Replace catalog with the full app seed (idempotent for empty businesses only).
delete from public.default_services;

insert into public.default_services(
  name, category, subcategory, gender, age_group, description, price, sort_order
)
values
  ('Simple Cutting', 'Hair Care & Styling', 'Simple Cutting', 'Male', 'Adult', '', 400::numeric, 1),
  ('Buzzcuts', 'Hair Care & Styling', 'Buzzcuts', 'Other', 'Adult', '', 1300::numeric, 2),
  ('Layers Cut', 'Hair Care & Styling', 'Layers Cut', 'Other', 'Adult', '', 3300::numeric, 3),
  ('Trims', 'Hair Care & Styling', 'Trims', 'Female', 'Adult', '', 700::numeric, 4),
  ('Manicure', 'Nail Care', 'Manicure', 'Other', 'Adult', '', 1000::numeric, 5),
  ('Pedicure', 'Nail Care', 'Pedicure', 'Other', 'Adult', '', 700::numeric, 6),
  ('Cleanup', 'Skincare & Facials', 'Cleanup', 'Female', 'Adult', '', 2200::numeric, 7),
  ('Basic Facial', 'Skincare & Facials', 'Basic Facial', 'Female', 'Adult', '', 1500::numeric, 8),
  ('Threading', 'Hair Removal', 'Threading', 'Female', 'Adult', '', 300::numeric, 9),
  ('Waxing Arms', 'Hair Removal', 'Waxing Arms', 'Female', 'Adult', '', 1200::numeric, 10),
  ('Eye Makeup', 'Eye & Makeup', 'Eye Makeup', 'Other', 'Adult', '', 1900::numeric, 11),
  ('Party Makeup', 'Eye & Makeup', 'Party Makeup', 'Other', 'Adult', '', 800::numeric, 12),
  ('Body Polish', 'Body & Wellness', 'Body Polish', 'Other', 'Adult', '', 1400::numeric, 13),
  ('Beard Trim', 'Men''s Grooming', 'Beard Trim', 'Male', 'Adult', '', 350::numeric, 14),
  ('Shave', 'Men''s Grooming', 'Shave', 'Male', 'Adult', '', 300::numeric, 15),
  ('Bridal Makeup', 'Bridal Services', 'Bridal Makeup', 'Other', 'Adult', '', 2800::numeric, 16),
  ('Kids Hair Cut', 'Kids Services', 'Kids Hair Cut', 'Male', 'Child', '', 500::numeric, 17),
  ('Head Massage', 'Spa & Massage', 'Head Massage', 'Other', 'Adult', '', 800::numeric, 18),
  ('Hair Spa', 'Hair Treatments', 'Hair Spa', 'Female', 'Adult', '', 1800::numeric, 19),
  ('Keratin', 'Hair Treatments', 'Keratin', 'Female', 'Adult', '', 2500::numeric, 20),
  ('Groom Package', 'Packages', 'Groom Package', 'Male', 'Adult', '', 2800::numeric, 21),
  ('Bridal Package', 'Packages', 'Bridal Package', 'Female', 'Adult', '', 8500::numeric, 22);

-- ---------------------------------------------------------------------------
-- Seed helpers (insert only when business lists are empty)
-- ---------------------------------------------------------------------------
create or replace function private.seed_business_services(business uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.services where business_id = business limit 1) then
    return;
  end if;
  insert into public.services(
    business_id, name, category, subcategory, gender, age_group, description, price, is_active
  )
  select
    business, d.name, d.category, d.subcategory, d.gender, d.age_group, d.description, d.price, true
  from public.default_services d
  order by d.sort_order, d.name;
end;
$$;

create or replace function private.seed_business_settings(business uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  expense text[];
  payment text[];
begin
  -- Columns already default to tax 17 / PKR; only fill empty list fields.
  select coalesce(array_agg(t.name order by t.sort_order, t.name), '{}')
  into expense
  from public.default_expense_types t;

  select coalesce(array_agg(p.label order by p.sort_order, p.label), '{}')
  into payment
  from public.default_payment_accounts p;

  update public.businesses b
  set
    currency_code = case
      when b.currency_code ~ '^[A-Z]{3}$' then b.currency_code
      else 'PKR'
    end,
    expense_types = case
      when cardinality(b.expense_types) = 0 then expense
      else b.expense_types
    end,
    payment_accounts = case
      when cardinality(b.payment_accounts) = 0 then payment
      else b.payment_accounts
    end
  where b.id = business;
end;
$$;

create or replace function private.seed_business_defaults(business uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.seed_business_settings(business);
  perform private.seed_business_services(business);
end;
$$;

create or replace function private.seed_defaults_on_business() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.seed_business_defaults(new.id);
  return new;
end;
$$;

drop trigger if exists seed_services_after_business on public.businesses;
drop trigger if exists seed_defaults_after_business on public.businesses;
create trigger seed_defaults_after_business
  after insert on public.businesses
  for each row execute function private.seed_defaults_on_business();

-- Backfill existing businesses (empty lists only; never overwrite CRUD).
do $$
declare b uuid;
begin
  for b in select id from public.businesses loop
    perform private.seed_business_defaults(b);
  end loop;
end $$;

create or replace function public.ensure_business_services(business uuid) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;
  perform private.seed_business_defaults(business);
end;
$$;

create or replace function public.ensure_business_defaults(business uuid) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  perform public.ensure_business_services(business);
end;
$$;

create or replace function public.get_business_settings(business uuid)
returns table (
  tax_rate numeric,
  currency_code text,
  expense_types text[],
  payment_accounts text[]
)
language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null
    or (
      not private.owns_business(business)
      and not exists (
        select 1 from public.business_employees e
        where e.business_id = business
          and e.profile_id = auth.uid()
          and e.join_status = 'accepted'
      )
      and not coalesce(private.is_admin(), false)
    )
  then
    raise exception 'Business access required' using errcode = '42501';
  end if;

  perform private.seed_business_defaults(business);

  return query
  select b.tax_rate, b.currency_code, b.expense_types, b.payment_accounts
  from public.businesses b
  where b.id = business;
end;
$$;

create or replace function public.update_business_settings(
  business uuid,
  new_tax_rate numeric default null,
  new_currency_code text default null,
  new_expense_types text[] default null,
  new_payment_accounts text[] default null
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not private.owns_business(business) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;

  update public.businesses b
  set
    tax_rate = coalesce(new_tax_rate, b.tax_rate),
    currency_code = coalesce(
      nullif(upper(trim(new_currency_code)), ''),
      b.currency_code
    ),
    expense_types = coalesce(new_expense_types, b.expense_types),
    payment_accounts = coalesce(new_payment_accounts, b.payment_accounts)
  where b.id = business;
end;
$$;

revoke all on function public.ensure_business_defaults(uuid) from public, anon;
revoke all on function public.get_business_settings(uuid) from public, anon;
revoke all on function public.update_business_settings(uuid, numeric, text, text[], text[]) from public, anon;
grant execute on function public.ensure_business_defaults(uuid) to authenticated;
grant execute on function public.get_business_settings(uuid) to authenticated;
grant execute on function public.update_business_settings(uuid, numeric, text, text[], text[]) to authenticated;

-- ============================================================================
-- 20261020040000_service_content_json_grants.sql
-- ============================================================================

-- Allow owners to persist Quill customer-view JSON on services.
grant insert (
  business_id, name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;

grant update (
  name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;

-- ============================================================================
-- 20261020050000_update_service_content.sql
-- ============================================================================

-- Persist Quill customer-view JSON even when column grants lag behind.
create or replace function public.update_service_content(
  service uuid,
  content jsonb,
  plain_description text default null
) returns public.services
language plpgsql
security invoker
set search_path = ''
as $$
declare
  row public.services;
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.services s
    where s.id = service and private.owns_business(s.business_id)
  ) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;

  update public.services s
  set
    content_json = coalesce(content, '[]'::jsonb),
    description = coalesce(nullif(trim(plain_description), ''), s.description)
  where s.id = service
  returning * into row;

  return row;
end;
$$;

revoke all on function public.update_service_content(uuid, jsonb, text) from public, anon;
grant execute on function public.update_service_content(uuid, jsonb, text) to authenticated;

-- Also grant column access for direct updates / inserts.
grant insert (
  business_id, name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;

grant update (
  name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;

-- ============================================================================
-- 20261020060000_update_service_content_name.sql
-- ============================================================================

-- Allow renaming the service title while saving customer-view content.
create or replace function public.update_service_content(
  service uuid,
  content jsonb,
  plain_description text default null,
  service_name text default null
) returns public.services
language plpgsql
security invoker
set search_path = ''
as $$
declare
  row public.services;
  clean_name text := nullif(trim(coalesce(service_name, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.services s
    where s.id = service and private.owns_business(s.business_id)
  ) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;

  update public.services s
  set
    content_json = coalesce(content, '[]'::jsonb),
    description = coalesce(nullif(trim(plain_description), ''), s.description),
    name = coalesce(clean_name, s.name)
  where s.id = service
  returning * into row;

  return row;
end;
$$;

revoke all on function public.update_service_content(uuid, jsonb, text, text) from public, anon;
grant execute on function public.update_service_content(uuid, jsonb, text, text) to authenticated;

-- ============================================================================
-- 20261020070000_payment_defaults_cash_card_online.sql
-- ============================================================================

-- Payment account defaults: Cash, Card, Online only.
-- Remove JazzCash / Easy from the catalog and from seeded business lists.

delete from public.default_payment_accounts
where label in ('Easy — Business', 'JazzCash — Business');

insert into public.default_payment_accounts(label, sort_order)
select * from (values
  ('Cash — Counter', 1),
  ('Card — POS', 2),
  ('Online — Bank transfer', 3)
) as v(label, sort_order)
on conflict (label) do update set sort_order = excluded.sort_order;

-- Drop the old defaults from businesses that already received them.
update public.businesses
set payment_accounts = coalesce((
  select array_agg(x order by ord)
  from unnest(payment_accounts) with ordinality as t(x, ord)
  where x not in ('Easy — Business', 'JazzCash — Business')
), '{}'::text[])
where payment_accounts && array['Easy — Business', 'JazzCash — Business']::text[];

-- ============================================================================
-- 20261020080000_invite_identity_execute_grants.sql
-- ============================================================================

-- Fix: public.invite_employee_by_identity is SECURITY INVOKER and calls private.*.
-- private was revoked from public/anon but never granted to authenticated, so
-- PostgREST returned "permission denied for function invite_employee_by_identity".

grant execute on function
  private.invite_employee_by_identity(uuid, text, text, text, text),
  private.pending_invites_for_me(),
  private.respond_to_employee_invite(uuid, boolean),
  private.set_employee_manager(uuid, boolean, text),
  private.verify_manager_pin(uuid, text),
  private.my_manager_businesses()
to authenticated;

-- ============================================================================
-- 20261020090000_team_phone_cnic_invite_consent.sql
-- ============================================================================

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

-- ============================================================================
-- 20261024140919_employee_invite_identity_policy.sql
-- ============================================================================

-- RLS policies execute with the caller's table privileges. Never reference
-- auth.users directly from an authenticated policy expression.
create or replace function private.invite_matches_current_user(invite_cnic text, invite_email text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.profiles p
    join auth.users u on u.id = p.user_id
    where p.user_id = (select auth.uid())
      and p.cnic = invite_cnic
      and lower(coalesce(u.email, '')) = lower(invite_email)
  );
$$;

revoke all on function private.invite_matches_current_user(text, text) from public, anon;
grant execute on function private.invite_matches_current_user(text, text) to authenticated;

drop policy if exists employee_invites_self_read on public.employee_invites;
create policy employee_invites_self_read on public.employee_invites
for select to authenticated using (
  status = 'pending'
  and (select private.invite_matches_current_user(cnic, email))
);

-- ============================================================================
-- 20261024144519_fix_business_photo_object_paths.sql
-- ============================================================================

-- Explicitly qualify the outer storage object: businesses also has a name column.
alter policy business_photo_upload on storage.objects
with check (bucket_id = 'business-photos' and exists (
  select 1 from public.businesses b
  where b.id::text = split_part(storage.objects.name, '/', 1)
    and b.owner_id = (select auth.uid())
));

alter policy business_photo_remove on storage.objects
using (bucket_id = 'business-photos' and exists (
  select 1 from public.businesses b
  where b.id::text = split_part(storage.objects.name, '/', 1)
    and b.owner_id = (select auth.uid())
));

alter policy business_photo_read on storage.objects
using (bucket_id = 'business-photos' and exists (
  select 1 from public.businesses b
  where b.id::text = split_part(storage.objects.name, '/', 1)
    and (b.is_active or b.owner_id = (select auth.uid()) or (select private.is_admin()))
));

-- ============================================================================
-- 20261024183056_employee_created_profiles_and_leave.sql
-- ============================================================================

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

-- ============================================================================
-- 20261024194022_pakistan_profile_date_validation.sql
-- ============================================================================

-- Calendar dates use the business timezone, including 00:00-04:59 Pakistan time.
-- Dates are not unique: many profiles may share a DOB and a work start date.
alter table public.profiles drop constraint profile_work_dates;
alter table public.profiles add constraint profile_work_dates check (
  work_started_on is null or (
    work_started_on <= (now() at time zone 'Asia/Karachi')::date and
    (date_of_birth is null or work_started_on >= date_of_birth)
  )
);

-- Owner-assisted employee onboarding must use the same calendar boundary.
create or replace function private.save_employee_record(business uuid, employee jsonb)
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
    or born is null or started is null or born>=(now() at time zone 'Asia/Karachi')::date or started<born or started>(now() at time zone 'Asia/Karachi')::date then
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

notify pgrst,'reload schema';

-- ============================================================================
-- 20261024200000_employee_self_service_rejoin.sql
-- ============================================================================

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

-- ============================================================================
-- 20261025020000_assisted_employee_contracts.sql
-- ============================================================================

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

-- ============================================================================
-- 20261025023000_employee_work_history.sql
-- ============================================================================

-- Return only the authenticated person's work and payments, including records
-- made before signup. Never return the salon's complete POS snapshot here.
create or replace function private.employee_work_history() returns jsonb
language sql stable security definer set search_path='' as $$
  with memberships as (
    select e.id,e.business_id,b.name,
      array[e.id::text,i.local_employee_id::text] as employee_ids,
      coalesce(s.payload,'{}'::jsonb) as payload, i.employee_data as assisted,
      coalesce(s.payload #> array['employees',e.id::text],
        s.payload #> array['employees',i.local_employee_id::text],i.employee_data,'{}'::jsonb) as employee
    from public.business_employees e
    join public.businesses b on b.id=e.business_id
    join public.profiles p on p.user_id=e.profile_id
    left join public.employee_invites i on i.business_id=e.business_id and i.cnic=p.cnic
    left join public.business_snapshots s on s.business_id=e.business_id
    where e.profile_id=(select auth.uid()) and e.join_status in ('accepted','left')
  ), named as (
    select *,lower(trim(concat_ws(' ',employee->>'firstName',employee->>'lastName'))) as employee_name
    from memberships
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'businessId',m.business_id,'businessName',m.name,'employeeId',m.id,
    'commission',coalesce(m.assisted #>> '{contract,commission}',nullif(m.employee->>'commission',''),'0'),
    'bills',(select coalesce(jsonb_agg(b.value),'[]'::jsonb)
      from jsonb_each(coalesce(m.payload->'bills','{}'::jsonb)) b
      where (nullif(b.value->>'employeeId','')=any(m.employee_ids))
        or (nullif(b.value->>'employeeId','') is null and m.employee_name<>''
          and lower(trim(b.value->>'employeeName'))=m.employee_name
          and not exists(select 1 from jsonb_each(coalesce(m.payload->'employees','{}'::jsonb)) other
            where not (other.key=any(array_remove(m.employee_ids,null)))
              and lower(trim(concat_ws(' ',other.value->>'firstName',other.value->>'lastName')))=m.employee_name))),
    'payouts',(select coalesce(jsonb_agg(p.value),'[]'::jsonb)
      from jsonb_each(coalesce(m.payload->'payouts','{}'::jsonb)) p
      where p.value->>'employeeId'=any(m.employee_ids))
  )),'[]'::jsonb) from named m;
$$;
create or replace function public.employee_work_history() returns jsonb
language sql stable security invoker set search_path='' as $$ select private.employee_work_history() $$;
revoke all on function private.employee_work_history(),public.employee_work_history() from public,anon;
grant execute on function private.employee_work_history(),public.employee_work_history() to authenticated;
notify pgrst,'reload schema';

-- ============================================================================
-- 20261025024500_employee_snapshot_privacy.sql
-- ============================================================================

-- Employee dashboards now use the scoped work-history RPC. Full POS payloads
-- (other staff records, expenses, settings) remain owner/manager/admin only.
alter policy snapshots_read on public.business_snapshots
using(private.owns_business(business_id) or (select private.is_admin()));

-- Refresh the Data API schema cache after successful commit.
notify pgrst, 'reload schema';
commit;
