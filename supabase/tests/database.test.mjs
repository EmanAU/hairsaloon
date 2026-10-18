import { createRequire } from 'node:module';
import { readFile, readdir } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test, before, after } from 'node:test';

const require = createRequire(new URL('../../web/package.json', import.meta.url));
const { PGlite } = require('@electric-sql/pglite');
const { btree_gist } = require('@electric-sql/pglite/contrib/btree_gist');
const db = new PGlite({ extensions: { btree_gist } });
const ids = Object.fromEntries(['admin', 'owner', 'owner2', 'employee', 'customer'].map((name, index) =>
  [name, `00000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`]));
let business, secondBusiness, membership, secondMembership, permanent;

async function as(name) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [ids[name] ?? '']);
  await db.exec(`set role ${name === 'anon' ? 'anon' : 'authenticated'}`);
}
async function scalar(sql, params = []) {
  const { rows } = await db.query(sql, params);
  return Object.values(rows[0])[0];
}
async function rejects(sql, params, code) {
  await assert.rejects(db.query(sql, params), error => error.code === code);
}

before(async () => {
  // Only the Auth identity helper is stubbed. All application SQL runs unchanged.
  await db.exec(`
    create role anon;
    create role authenticated;
    create schema auth;
    create schema storage;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,delete on storage.objects to authenticated;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema public, auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    alter default privileges in schema public grant all on tables to anon, authenticated;
  `);
  const directory = new URL('../migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(name => name.endsWith('.sql')).sort()) {
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
  }
  for (const [name, id] of Object.entries(ids)) {
    await db.query('insert into auth.users values ($1)', [id]);
    await as(name);
    await db.query('insert into public.users(id, display_name) values ($1, $2)', [id, name]);
    await db.exec('reset role');
  }
  await db.query("update public.users set role = 'superadmin' where id = $1", [ids.admin]);
});
after(async () => db.close());

test('business photo bucket is private with a 2 MB image limit', async () => {
  await db.exec('reset role');
  const { rows: [bucket] } = await db.query("select public,file_size_limit,allowed_mime_types from storage.buckets where id='business-photos'");
  assert.equal(bucket.public, false);
  assert.equal(Number(bucket.file_size_limit), 2097152);
  assert.deepEqual(bucket.allowed_mime_types, ['image/jpeg','image/png','image/webp']);
});

test('profile bucket is private with a 2 MB upload limit', async () => {
  await db.exec('reset role');
  const { rows: [bucket] } = await db.query("select public, file_size_limit from storage.buckets where id='profile-photos'");
  assert.equal(bucket.public, false);
  assert.equal(Number(bucket.file_size_limit), 2097152);
});

test('users cannot self-promote or create another identity', async () => {
  await as('owner');
  await rejects("update public.users set role = 'superadmin' where id = $1", [ids.owner], '42501');
  await rejects("insert into public.users(id, display_name, role) values ($1, 'bad', 'superadmin')", [ids.owner], '42501');
  assert.equal(await scalar('select count(*)::int from public.users'), 1);
});

test('businesses start inactive and only superadmin can approve', async () => {
  for (const name of ['owner', 'owner2']) {
    await as(name);
    const id = await scalar(`insert into public.businesses(owner_id,name,phone,business_type,city,area,address)
      values ($1,'Test salon','03000000000','salon','Lahore','Test','Test address') returning id`, [ids[name]]);
    if (name === 'owner') business = id; else secondBusiness = id;
    assert.equal(await scalar('select is_active from public.businesses where id=$1', [id]), false);
    await db.query('insert into public.business_invites(business_id) values ($1)', [id]);
    await rejects('update public.businesses set is_active=true where id=$1', [id], '42501');
    await rejects('select public.review_business($1,true)', [id], '42501');
    await as('admin');
    await db.query('select public.review_business($1,true)', [id]);
  }
  await as('owner2');
  assert.equal(await scalar('select count(*)::int from public.business_invites where business_id=$1', [business]), 0);
  assert.equal((await db.query("update public.businesses set name='stolen' where id=$1 returning id", [business])).rows.length, 0);
});

test('profiles and permanent codes are private and immutable', async () => {
  await as('employee');
  await db.query("insert into public.profiles(user_id,cnic,date_of_birth,phone) values ($1,'0000000000000','2000-01-01','03000000000')", [ids.employee]);
  const code = await scalar('select code from public.profiles where user_id=$1', [ids.employee]);
  await db.query("update public.profiles set work_started_on='2016-05-01' where user_id=$1", [ids.employee]);
  assert.equal(await scalar('select code from public.profiles where user_id=$1', [ids.employee]), code);
  await rejects("update public.profiles set work_started_on='1999-01-01' where user_id=$1", [ids.employee], '23514');
  await rejects("update public.profiles set work_started_on=current_date+1 where user_id=$1", [ids.employee], '23514');
  await rejects('update public.profiles set code=gen_random_uuid()', [], '42501');
  await as('customer');
  assert.equal(await scalar('select count(*)::int from public.profiles'), 0);
  await as('admin');
  assert.equal(await scalar('select count(*)::int from public.profiles'), 1);
});

test('code joining is idempotent and owners cannot accept for employees', async () => {
  await as('owner');
  const invite = await scalar('select code from public.business_invites where business_id=$1', [business]);
  await as('employee');
  membership = await scalar('select public.request_join($1)', [invite]);
  assert.equal(await scalar('select public.request_join($1)', [invite]), membership);
  const profileCode = await scalar('select code from public.profiles');
  await as('owner2');
  secondMembership = await scalar('select public.invite_employee($1,$2)', [secondBusiness, profileCode]);
  await as('owner');
  permanent = await scalar(`select public.propose_contract($1,'permanent',now(),null,10000,10,'Monthly salary')`, [membership]);
  await rejects('select public.respond_to_contract($1,true)', [permanent], '42501');
  await as('employee');
  await db.query('select public.respond_to_contract($1,true)', [permanent]);
  await rejects('update public.employee_contracts set salary=999999 where id=$1', [permanent], '42501');
});

test('accepted permanent contracts block a second salon until release', async () => {
  await as('owner2');
  const next = await scalar(`select public.propose_contract($1,'fixed',now(),now()+interval '2 days',100,0,'Test')`, [secondMembership]);
  await as('employee');
  await rejects('select public.respond_to_contract($1,true)', [next], '23P01');
  await as('customer');
  await rejects("select public.release_contract($1,'unauthorized')", [permanent], '42501');
  await as('owner');
  await db.query("select public.release_contract($1,'Employee moving salons')", [permanent]);
  // Start the replacement after the release; historical overlap is also rejected.
  await as('owner2');
  const replacement = await scalar(`select public.propose_contract($1,'fixed',now(),now()+interval '2 days',100,0,'New contract')`, [secondMembership]);
  await as('employee');
  await db.query('select public.respond_to_contract($1,true)', [replacement]);
  assert.equal(await scalar('select count(*)::int from public.contract_reminders'), 1);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from public.contract_reminders'), 0);
  assert.equal(await scalar('select count(*)::int from public.employee_contracts'), 0);
});

test('daily contracts enforce 24 hours and permanent contracts reject an end date', async () => {
  await as('owner');
  await rejects(`select public.propose_contract($1,'daily',now(),now()+interval '2 days',0,0,'')`, [membership], '23514');
  await rejects(`select public.propose_contract($1,'permanent',now(),now()+interval '2 days',0,0,'')`, [membership], '23514');
  await rejects(`select public.propose_contract($1,'fixed',now(),now()+interval '2 days',-1,0,'')`, [membership], '23514');
});

test('only owners edit rate lists; inactive businesses disappear from discovery', async () => {
  await as('owner');
  const service = await scalar(`insert into public.services(business_id,name,category,price)
    values ($1,'Haircut','Hair',500) returning id`, [business]);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from public.services where id=$1', [service]), 1);
  assert.equal((await db.query('update public.services set price=1 where id=$1 returning id', [service])).rows.length, 0);
  await as('admin');
  await db.query('select public.review_business($1,false)', [business]);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from public.services where id=$1', [service]), 0);
  assert.equal(await scalar('select count(*)::int from public.businesses where id=$1', [business]), 0);
});

test('anonymous callers have neither data access nor workflow execution', async () => {
  await as('anon');
  await rejects('select * from public.profiles', [], '42501');
  await rejects('select public.review_business($1,true)', [business], '42501');
  await rejects('select public.request_join($1)', [business], '42501');
});

test('ended contracts permit a new contract without a scheduled expiry job', async () => {
  await db.exec('reset role');
  const customer = ids.customer;
  await db.query("insert into public.profiles(user_id, phone) values ($1,'03000000001')", [customer]);
  const employee = await scalar('insert into public.business_employees(business_id,profile_id,requested_by) values ($1,$2,$2) returning id', [secondBusiness, customer]);
  await db.query(`insert into public.employee_contracts(employee_id,profile_id,kind,starts_at,ends_at,status,accepted_at)
    values ($1,$2,'daily',now()-interval '2 days',now()-interval '1 day','accepted',now()-interval '2 days')`, [employee, customer]);
  await as('owner2');
  const contract = await scalar("select public.propose_contract($1,'daily',now(),now()+interval '12 hours',100,0,'')", [employee]);
  await as('customer');
  await db.query('select public.respond_to_contract($1,true)', [contract]);
  assert.equal(await scalar('select count(*)::int from public.contract_reminders'), 1);
});

test('touching contract boundaries are allowed but one-second overlaps are rejected', async () => {
  await as('owner2');
  const employee = await scalar('select id from public.business_employees where business_id=$1 and profile_id=$2', [secondBusiness, ids.customer]);
  const ends = await scalar("select ends_at from public.employee_contracts where employee_id=$1 and status='accepted' order by ends_at desc limit 1", [employee]);
  const touching = await scalar("select public.propose_contract($1,'daily',$2::timestamptz,$2::timestamptz+interval '12 hours',100,0,'')", [employee, ends]);
  const overlapping = await scalar("select public.propose_contract($1,'daily',$2::timestamptz-interval '1 second',$2::timestamptz+interval '6 hours',100,0,'')", [employee, ends]);
  await as('customer');
  await db.query('select public.respond_to_contract($1,true)', [touching]);
  await rejects('select public.respond_to_contract($1,true)', [overlapping], '23P01');
});

test('suspended businesses cannot receive new joins or contract proposals', async () => {
  await as('owner');
  const invite = await scalar('select code from public.business_invites where business_id=$1', [business]);
  await rejects("select public.propose_contract($1,'permanent',now(),null,0,0,'')", [membership], 'P0001');
  await as('customer');
  await rejects('select public.request_join($1)', [invite], 'P0001');
});

test('staff discovery exposes only active workers and no private profile fields', async () => {
  await as('customer');
  const active = await db.query('select * from public.business_staff($1)', [secondBusiness]);
  assert.ok(active.rows.length > 0);
  assert.deepEqual(Object.keys(active.rows[0]).sort(), ['display_name', 'is_working', 'membership_id', 'profile_id']);
  assert.ok(active.rows.every(row => row.is_working));
  assert.equal((await db.query('select * from public.business_staff($1)', [business])).rows.length, 0);
  await as('owner');
  assert.equal((await db.query('select * from public.business_staff($1)', [business])).rows.length, 1);
  await as('anon');
  await rejects('select * from public.business_staff($1)', [secondBusiness], '42501');
});

test('reviews validate ratings, prevent self-review and preserve author ownership', async () => {
  await as('admin');
  await db.query('select public.review_business($1,true)', [business]);
  await as('customer');
  const review = await scalar("insert into public.reviews(business_id,rating,body) values ($1,5,'Good haircut') returning id", [business]);
  await rejects("insert into public.reviews(business_id,rating,body) values ($1,4,'Duplicate')", [business], '23505');
  await rejects("update public.reviews set rating=6 where id=$1", [review], '23514');
  await rejects("update public.reviews set author_id=$1 where id=$2", [ids.owner, review], '42501');
  await rejects("insert into public.reviews(business_id,employee_id,rating,body) values ($1,$2,5,'Wrong salon')", [business, secondMembership], '23514');
  await as('owner');
  await rejects("insert into public.reviews(business_id,rating,body) values ($1,5,'My salon')", [business], '42501');
  assert.equal((await db.query("update public.reviews set body='tampered' where id=$1 returning id", [review])).rows.length, 0);
  assert.equal((await db.query('delete from public.reviews where id=$1 returning id', [review])).rows.length, 0);
  await as('customer');
  await db.query("update public.reviews set body='Updated review' where id=$1", [review]);
  await as('admin');
  assert.equal((await db.query('delete from public.reviews where id=$1 returning id', [review])).rows.length, 1);
});

test('barber QR resolves active employment only', async () => {
  await as('owner');
  assert.equal(await scalar('select public.resolve_barber($1)', [membership]), null);
  assert.equal(await scalar('select public.resolve_barber($1)', [secondMembership]), secondBusiness);
  await as('anon');
  await rejects('select public.resolve_barber($1)', [secondMembership], '42501');
});

test('storage access follows owner, service publication and path boundaries', async () => {
  await as('owner');
  const service = await scalar("insert into public.services(business_id,name,category,price) values ($1,'Photo service','Hair',100) returning id", [business]);
  const path = `${business}/${service}/photo.jpg`;
  await db.query("insert into storage.objects(bucket_id,name) values ('service-media',$1)", [path]);
  await db.query("insert into public.service_media(service_id,kind,storage_path) values ($1,'photo',$2)", [service, path]);
  await rejects("insert into public.service_media(service_id,kind,storage_path) values ($1,'photo',$2)", [service, `${secondBusiness}/${service}/stolen.jpg`], '23514');
  await as('owner2');
  await rejects("insert into storage.objects(bucket_id,name) values ('service-media',$1)", [path], '42501');
  assert.equal((await db.query('delete from storage.objects where name=$1 returning id', [path])).rows.length, 0);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1', [path]), 1);
  await as('owner');
  await db.query('update public.services set is_active=false where id=$1', [service]);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1', [path]), 0);
  await as('employee');
  const photo = `${ids.employee}/profile.jpg`;
  await db.query("insert into storage.objects(bucket_id,name) values ('profile-photos',$1)", [photo]);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1', [photo]), 0);
});

test('sync is owner scoped, atomic, retry safe and detects competing device changes', async () => {
  const first='10000000-0000-4000-8000-000000000001';
  const second='10000000-0000-4000-8000-000000000002';
  const payload={bills:{bill1:{total:500}},phones:{}};
  await as('owner');
  assert.deepEqual(await scalar('select public.sync_business($1,0,$2,$3)', [business,first,payload]), {conflict:false,revision:1});
  assert.deepEqual(await scalar('select public.sync_business($1,0,$2,$3)', [business,first,payload]), {conflict:false,revision:1});
  await rejects('select public.sync_business($1,0,$2,$3)', [business,first,{bills:{}}], '22023');
  assert.deepEqual(await scalar('select public.sync_business($1,0,$2,$3)', [business,second,{bills:{}}]), {conflict:true,revision:1});
  assert.deepEqual(await scalar('select payload from public.business_snapshots where business_id=$1',[business]),payload);
  await rejects('update public.business_snapshots set revision=100',[],'42501');
  await as('owner2');
  assert.equal(await scalar('select count(*)::int from public.business_snapshots'),0);
  await rejects('select public.sync_business($1,1,$2,$3)',[business,second,{}],'42501');
  await as('owner');
  assert.deepEqual(await scalar('select public.sync_business($1,1,$2,$3)',[business,second,{bills:{}}]),{conflict:false,revision:2});
  await as('anon');
  await rejects('select * from public.business_snapshots',[],'42501');
});

test('business photos follow ownership and approval', async () => {
  const path = `${business}/business.png`;
  await as('owner');
  await db.query("insert into storage.objects(bucket_id,name) values ('business-photos',$1)", [path]);
  await db.query('update public.businesses set logo_path=$1 where id=$2', [path,business]);
  await rejects('update public.businesses set logo_path=$1 where id=$2', [`${secondBusiness}/wrong.png`,business], '23514');
  await as('owner2');
  await rejects("insert into storage.objects(bucket_id,name) values ('business-photos',$1)", [path], '42501');
  assert.equal((await db.query('delete from storage.objects where name=$1 returning id', [path])).rows.length, 0);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1', [path]), 1);
  await as('admin');
  await db.query('select public.review_business($1,false)', [business]);
  await as('customer');
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1', [path]), 0);
  await as('owner');
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1', [path]), 1);
  await as('admin');
  await db.query('select public.review_business($1,true)', [business]);
});

test('public barber photos reveal only linked active photos, never private profile fields', async () => {
  await as('employee');
  const path=`${ids.employee}/profile.jpg`;
  await db.query('update public.profiles set photo_path=$1 where user_id=$2',[path,ids.employee]);
  await rejects('update public.profiles set photo_path=$1 where user_id=$2',[`${ids.owner}/stolen.jpg`,ids.employee],'23514');
  await as('owner');
  assert.equal(await scalar('select public.barber_photo($1)',[secondMembership]),path);
  assert.equal(await scalar('select public.barber_photo($1)',[membership]),null);
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1',[path]),1);
  assert.equal(await scalar('select count(*)::int from public.profiles where user_id=$1',[ids.employee]),0);
  await as('owner2');
  const contract=await scalar("select id from public.employee_contracts where employee_id=$1 and status='accepted' and starts_at<=now() and (ends_at is null or ends_at>now()) limit 1",[secondMembership]);
  await db.query("select public.release_contract($1,'Leaving salon')",[contract]);
  await as('owner');
  assert.equal(await scalar('select public.barber_photo($1)',[secondMembership]),null);
  assert.equal(await scalar('select count(*)::int from storage.objects where name=$1',[path]),0);
});
