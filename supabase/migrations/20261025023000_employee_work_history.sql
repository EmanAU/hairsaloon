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
