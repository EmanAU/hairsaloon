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
