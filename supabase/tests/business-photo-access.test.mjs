import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';
const require = createRequire(new URL('../../web/package.json', import.meta.url));
const { PGlite } = require('@electric-sql/pglite');

test('business photos use object paths, allow pending owners, and isolate other shops', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role authenticated; create role anon;
      create schema auth; create schema private; create schema storage;
      create function auth.uid() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'') $$;
      create function private.is_admin() returns boolean language sql stable as $$ select auth.uid()='admin' $$;
      create table public.businesses(id text primary key, owner_id text, name text, is_active boolean);
      insert into public.businesses values ('pending','owner','Ali Salon',false), ('active','other','Another Salon',true);
      create table storage.objects(bucket_id text, name text);
      grant usage on schema public,auth,private,storage to authenticated;
      grant select on public.businesses to authenticated;
      grant select,insert,delete on storage.objects to authenticated;
      alter table storage.objects enable row level security;
      create policy business_photo_upload on storage.objects for insert to authenticated with check(bucket_id='business-photos' and exists(select 1 from public.businesses b where b.id::text=split_part(b.name,'/',1) and b.owner_id=auth.uid()));
      create policy business_photo_remove on storage.objects for delete to authenticated using(bucket_id='business-photos' and exists(select 1 from public.businesses b where b.id::text=split_part(b.name,'/',1) and b.owner_id=auth.uid()));
      create policy business_photo_read on storage.objects for select to authenticated using(bucket_id='business-photos' and exists(select 1 from public.businesses b where b.id::text=split_part(b.name,'/',1) and (b.is_active or b.owner_id=auth.uid() or private.is_admin())));
      select set_config('request.jwt.claim.sub','owner',false); set role authenticated;
    `);
    await assert.rejects(db.exec("insert into storage.objects values ('business-photos','pending/logo.jpg')"), error => error.code === '42501');
    await db.exec('reset role');
    await db.exec(await readFile(new URL('../migrations/20261024144519_fix_business_photo_object_paths.sql', import.meta.url), 'utf8'));
    async function asUser(user) {
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,false)", [user]);
      await db.exec('set role authenticated');
    }
    await asUser('owner');
    await db.exec("insert into storage.objects values ('business-photos','pending/logo.jpg')");
    assert.equal((await db.query('select * from storage.objects')).rows.length, 1);
    await assert.rejects(db.exec("insert into storage.objects values ('business-photos','active/foreign.jpg')"), error => error.code === '42501');
    await assert.rejects(db.exec("insert into storage.objects values ('profile-photos','pending/wrong-bucket.jpg')"), error => error.code === '42501');
    await asUser('other');
    assert.equal((await db.query('select * from storage.objects')).rows.length, 0);
    assert.equal((await db.query('delete from storage.objects returning *')).rows.length, 0);
    await db.exec("insert into storage.objects values ('business-photos','active/logo.jpg')");
    await asUser('viewer');
    assert.deepEqual((await db.query('select name from storage.objects')).rows, [{name:'active/logo.jpg'}]);
    await asUser('admin');
    assert.equal((await db.query('select * from storage.objects')).rows.length, 2);
    await asUser('owner');
    assert.equal((await db.query("delete from storage.objects where name='pending/logo.jpg' returning *")).rows.length, 1);
    await db.exec('reset role; set role anon');
    await assert.rejects(db.query('select * from storage.objects'), error => error.code === '42501');
  } finally { await db.close(); }
});
