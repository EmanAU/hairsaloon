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
