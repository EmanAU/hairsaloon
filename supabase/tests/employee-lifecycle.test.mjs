import {createRequire} from 'node:module';
import {readFile,readdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';
const require=createRequire(new URL('../../web/package.json',import.meta.url));
const {PGlite}=require('@electric-sql/pglite');
const {btree_gist}=require('@electric-sql/pglite/contrib/btree_gist');
test('owner-created employee: verified invite before profile, membership status, leave and business creation',async()=>{
 const db=new PGlite({extensions:{btree_gist}});
 const owner='00000000-0000-4000-8000-000000000001', employee='00000000-0000-4000-8000-000000000002', outsider='00000000-0000-4000-8000-000000000003', localId='00000000-0000-4000-8000-000000000004';
 try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
   create schema auth; create schema storage;
   create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
   create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
   create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
   create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
   alter table storage.objects enable row level security;
   grant usage on schema auth,storage to authenticated;
   grant select,insert,delete on storage.objects to authenticated;`);
  for (const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort()) {
   const sql=(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8')).replace(/create extension if not exists pgcrypto with schema extensions;/i,'-- pgcrypto unavailable in PGlite; no crypto paths called');
   try { await db.exec(sql); } catch(e) { throw new Error(`${file}: ${e.message}`); }
  }
  await db.query("insert into auth.users values ($1,'owner@test.example',now()),($2,'staff@test.example',now()),($3,'other@test.example',now())",[owner,employee,outsider]);
  await db.query("insert into public.users(id,display_name) values ($1,'Owner'),($2,'Google name'),($3,'Other')",[owner,employee,outsider]);
  const business=(await db.query("insert into public.businesses(owner_id,name,phone,business_type,city,area,address,is_active) values($1,'Test Salon','03001234567','Salon','Lahore','Area','Address',true) returning id",[owner])).rows[0].id;
  async function as(id){ await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec('set role authenticated'); }
  const record={id:localId,firstName:'Hassan',lastName:'Ali',email:'staff@test.example',phoneNumber:'+923001234568',cnicNumber:'1234512345671',dateOfBirth:'1997-01-01',workStartedOn:'2016-01-01',homeAddress:'Street 1',isActive:true,photoBase64:'cGhvdG8='};
  await as(owner);
  await db.query('select public.save_employee_record($1,$2)',[business,record]);
  await db.query('select public.save_employee_record($1,$2)',[business,record]);
  assert.equal((await db.query('select count(*)::int n from public.employee_invites')).rows[0].n,1);
  const invitation=(await db.query('select id from public.employee_invites')).rows[0].id;
  await as(outsider);
  assert.equal((await db.query('select * from public.pending_invites_for_me()')).rows.length,0);
  await assert.rejects(db.query('select public.respond_to_employee_invite_profile($1,true)',[invitation]),e=>e.code==='42501');
  await assert.rejects(db.query('select public.save_employee_record($1,$2)',[business,record]),e=>e.code==='42501');
  await as(employee);
  assert.equal((await db.query('select * from public.pending_invites_for_me()')).rows.length,1);
  assert.equal((await db.query('select * from public.profiles')).rows.length,0);
  const response=(await db.query('select public.respond_to_employee_invite_profile($1,true) data',[invitation])).rows[0].data;
  assert.equal(response.photoBase64,record.photoBase64);
  assert.equal((await db.query('select phone,cnic from public.profiles')).rows[0].cnic,record.cnicNumber);
  assert.equal((await db.query('select id from public.business_employees')).rows[0].id,localId);
  await db.query('select public.respond_to_employee_invite_profile($1,true)',[invitation]);
  await assert.rejects(db.query("insert into public.businesses(owner_id,name,phone,business_type,city,area,address) values($1,'Blocked','03001234567','Salon','Lahore','Area','Address')",[employee]),e=>e.code==='42501');
  await as(owner);
  assert.equal((await db.query('select is_active from public.business_team($1)',[business])).rows[0].is_active,true);
  await db.query('select public.set_employee_active($1,false)',[localId]);
  assert.equal((await db.query('select is_active from public.business_team($1)',[business])).rows[0].is_active,false);
  await db.query('select public.set_employee_active($1,true)',[localId]);
  await db.exec('reset role');
  await db.query("insert into public.employee_contracts(employee_id,profile_id,kind,starts_at,ends_at,status,accepted_at) values($1,$2,'fixed',now()-interval '1 day',now()+interval '30 days','accepted',now()-interval '1 day')",[localId,employee]);
  await db.query("update public.business_employees set is_manager=true,manager_pin_hash='test-hash' where id=$1",[localId]);
  await as(outsider);
  await assert.rejects(db.query('select public.leave_business($1)',[business]),e=>e.code==='42501');
  await as(employee);
  await db.query('select public.leave_business($1)',[business]);
  const membership=(await db.query('select join_status,is_active,is_manager,manager_pin_hash from public.business_employees')).rows[0];
  assert.deepEqual(membership,{join_status:'left',is_active:false,is_manager:false,manager_pin_hash:null});
  assert.equal((await db.query('select status from public.employee_contracts')).rows[0].status,'released');
  await db.query('select public.leave_business($1)',[business]);
  // Leaving does not remove the educated employee's code/QR joining path.
  await db.exec('reset role');
  const code=(await db.query('insert into public.business_invites(business_id) values($1) on conflict(business_id) do update set business_id=excluded.business_id returning code',[business])).rows[0].code;
  await as(employee);
  await db.query('select public.request_join($1)',[code]);
  assert.equal((await db.query('select join_status from public.business_employees')).rows[0].join_status,'pending');
  await as(owner);
  await db.query('select public.review_join($1,true)',[localId]);
  assert.deepEqual((await db.query('select join_status,is_active from public.business_team($1)',[business])).rows[0],{join_status:'accepted',is_active:true});
  await as(employee);
  await db.query('select public.leave_business($1)',[business]);
  await db.query("insert into public.businesses(owner_id,name,phone,business_type,city,area,address) values($1,'Own shop','03001234567','Salon','Lahore','Area','Address')",[employee]);
  await as(owner);
  const left=(await db.query('select join_status,is_active from public.business_team($1)',[business])).rows[0];
  assert.deepEqual(left,{join_status:'left',is_active:false});
  await db.exec('reset role; set role anon');
  await assert.rejects(db.query('select public.leave_business($1)',[business]),e=>e.code==='42501');
 } finally { await db.close(); }
});
