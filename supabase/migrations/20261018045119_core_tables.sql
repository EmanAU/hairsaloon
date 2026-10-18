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
