import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';
const require = createRequire(new URL('../../web/package.json', import.meta.url));
const { PGlite } = require('@electric-sql/pglite');

test('invite policy avoids auth.users permission errors and preserves tenant/identity isolation', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role authenticated; create role anon;
      create schema auth; create schema private;
      create table auth.users(id text primary key, email text);
      create function auth.uid() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'') $$;
      create table public.profiles(user_id text primary key, cnic text);
      create table public.businesses(id text primary key, owner_id text);
      create table public.employee_invites(id text primary key, business_id text, cnic text, email text, status text);
      insert into auth.users values ('owner','owner@example.test'), ('employee','staff@example.test'), ('stranger','other@example.test');
      insert into public.profiles values ('employee','1234512345671'), ('stranger','1234512345671');
      insert into public.businesses values ('a','owner'), ('b','another-owner');
      insert into public.employee_invites values
        ('own-pending','a','1234512345671','STAFF@example.test','pending'),
        ('own-declined','a','9999999999999','declined@example.test','declined'),
        ('foreign','b','8888888888888','foreign@example.test','pending');
      grant usage on schema public,auth,private to authenticated;
      grant select on public.profiles,public.businesses,public.employee_invites to authenticated;
      alter table public.employee_invites enable row level security;
      create function private.owns_business(business text) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.businesses where id=business and owner_id=auth.uid()) $$;
      create policy employee_invites_owner_all on public.employee_invites for all to authenticated using(private.owns_business(business_id));
      create policy employee_invites_self_read on public.employee_invites for select to authenticated using(status='pending' and exists(select 1 from public.profiles p join auth.users u on u.id=p.user_id where p.user_id=auth.uid() and p.cnic=employee_invites.cnic and lower(u.email)=lower(employee_invites.email)));
      select set_config('request.jwt.claim.sub','owner',false); set role authenticated;
    `);
    await assert.rejects(db.query('select id from public.employee_invites'), error => error.code === '42501');
    await db.exec('reset role');
    await db.exec(await readFile(new URL('../migrations/20261024140919_employee_invite_identity_policy.sql', import.meta.url), 'utf8'));
    async function readAs(user) {
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,false)", [user]);
      await db.exec('set role authenticated');
      return (await db.query('select id from public.employee_invites order by id')).rows.map(row => row.id);
    }
    assert.deepEqual(await readAs('owner'), ['own-declined','own-pending']);
    assert.deepEqual(await readAs('employee'), ['own-pending']);
    assert.deepEqual(await readAs('stranger'), []);
    assert.deepEqual(await readAs(''), []);
    await db.exec('reset role; set role anon');
    await assert.rejects(db.query('select id from public.employee_invites'), error => error.code === '42501');
  } finally { await db.close(); }
});
