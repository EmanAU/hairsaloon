-- Publish membership changes for the live owner inbox and join-request queue.
-- Existing authenticated SELECT policies still authorize every delivery.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'business_employees'
     ) then
    alter publication supabase_realtime add table public.business_employees;
  end if;
end;
$$;
