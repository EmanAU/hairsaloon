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
