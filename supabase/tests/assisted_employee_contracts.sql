-- Run only in the isolated schema harness; fixtures are rolled back.
begin;
insert into auth.users(id,email,email_confirmed_at) values
('10000000-0000-4000-8000-000000000001','owner@test.example',now()),
('10000000-0000-4000-8000-000000000002','employee@test.example',now()),
('10000000-0000-4000-8000-000000000003','stranger@test.example',now());
insert into public.users(id,display_name) values
('10000000-0000-4000-8000-000000000001','Owner'),
('10000000-0000-4000-8000-000000000002','Employee'),
('10000000-0000-4000-8000-000000000003','Stranger');
insert into public.businesses(id,owner_id,name,phone,business_type,city,area,address,is_active)
values('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
'Test Salon','03465501748','Salon','Lahore','Area','Road',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select public.save_employee_record('20000000-0000-4000-8000-000000000001',
'{"id":"30000000-0000-4000-8000-000000000001","firstName":"Employee","lastName":"","email":"employee@test.example","phoneNumber":"03465501748","cnicNumber":"1234512345671","dateOfBirth":"1995-01-01","workStartedOn":"2015-01-01","isActive":true,"commission":"40","basicSalary":"5000","contract":{"id":"40000000-0000-4000-8000-000000000001","kind":"permanent","startsAt":"2026-01-01T00:00:00Z","endsAt":null,"salary":5000,"commission":40,"terms":"Owner pays the discount"}}'::jsonb);
do $$ begin
  if exists(select 1 from public.employee_contracts) then raise exception 'Contract materialized before identity linked'; end if;
  if exists(select 1 from public.business_employees) then raise exception 'Auth membership was fabricated'; end if;
  begin
    update public.employee_invites set employee_data=jsonb_set(employee_data,'{contract,commission}','101'::jsonb);
    raise exception 'Invalid commission accepted';
  exception when raise_exception then
    if sqlerrm='Invalid commission accepted' then raise; end if;
  end;
end $$;
-- Owner records work and a payment before this person has a profile or joins.
select public.sync_business('20000000-0000-4000-8000-000000000001',0,
'50000000-0000-4000-8000-000000000001',
'{"employees":{"30000000-0000-4000-8000-000000000001":{"firstName":"Employee","lastName":"","commission":"40"},"30000000-0000-4000-8000-000000000002":{"firstName":"Other","lastName":""}},
"bills":{"legacy":{"id":"legacy","employeeName":"Employee","subTotal":1000},"stable":{"id":"stable","employeeId":"30000000-0000-4000-8000-000000000001","employeeName":"Old name","subTotal":1000},"other":{"id":"other","employeeId":"30000000-0000-4000-8000-000000000002","subTotal":999}},
"payouts":{"mine":{"id":"mine","employeeId":"30000000-0000-4000-8000-000000000001","amount":200},"theirs":{"employeeId":"30000000-0000-4000-8000-000000000002","amount":999}},"settings":{"secret":"OWNER-ONLY"}}'::jsonb);
reset role;
-- Store the invite id in a setting without exposing other users' invite rows.
select set_config('test.invite',(select id::text from public.employee_invites where email='employee@test.example'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$ begin
  begin
    perform public.respond_to_employee_invite_profile(current_setting('test.invite')::uuid,true);
    raise exception 'Stranger accepted the invite';
  exception when insufficient_privilege then null;
  end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select public.respond_to_employee_invite_profile(current_setting('test.invite')::uuid,true);
select public.respond_to_employee_invite_profile(current_setting('test.invite')::uuid,true);
do $$ begin
  if (select count(*) from public.employee_contracts)<>1 then raise exception 'Contract duplicated or missing'; end if;
  if not exists(select 1 from public.employee_contracts where
    employee_id='30000000-0000-4000-8000-000000000001' and
    profile_id='10000000-0000-4000-8000-000000000002' and salary=5000 and
    commission_percent=40 and status='accepted' and terms='Owner pays the discount') then
    raise exception 'Saved terms did not reach the employee';
  end if;
end $$;
do $$ declare history jsonb := public.employee_work_history(); begin
  if exists(select 1 from public.business_snapshots) then raise exception 'Employee can read full POS payload'; end if;
  if jsonb_array_length(history)<>1 or jsonb_array_length(history->0->'bills')<>2
    or jsonb_array_length(history->0->'payouts')<>1 then raise exception 'Old work or payment missing'; end if;
  if history::text like '%OWNER-ONLY%' or history::text like '%999%' then raise exception 'Coworker or owner data exposed'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$ begin
  if public.employee_work_history()<>'[]'::jsonb then raise exception 'Stranger can read work history'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select public.leave_business('20000000-0000-4000-8000-000000000001');
do $$ begin
  if jsonb_array_length(public.employee_work_history()->0->'bills')<>2 then raise exception 'Own historical work lost after leaving'; end if;
end $$;
rollback;
