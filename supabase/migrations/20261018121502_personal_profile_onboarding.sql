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
