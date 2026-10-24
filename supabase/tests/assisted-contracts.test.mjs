import fs from 'node:fs';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
import test from 'node:test';
const localRequire=createRequire(new URL('../../web/package.json', import.meta.url));
const {PGlite}=localRequire('@electric-sql/pglite');
const {btree_gist}=localRequire('@electric-sql/pglite/contrib/btree_gist');
test('assisted contracts preserve pre-login work, settlements and privacy', async()=>{
 const db=new PGlite({extensions:{btree_gist}});
 try{
  await db.exec(`
   create role anon; create role authenticated; create role service_role;
   create schema auth; create schema storage;
   create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
   create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
   create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
   create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
   alter table storage.objects enable row level security;
   grant usage on schema public,auth,storage to anon,authenticated,service_role;
   grant select,insert,delete on storage.objects to authenticated;
  `);
  // PGlite lacks pgcrypto. Skip only extension installation for DDL validation;
  // shipped SQL is unchanged. PIN cryptography is not exercised in this check.
  const sql=fs.readFileSync(new URL('../../docs/backend/trim-matrix-full-backend.sql', import.meta.url),'utf8');
  await db.exec(sql.replace(/create extension if not exists pgcrypto with schema extensions;/i,'-- pgcrypto unavailable in PGlite DDL harness'));
  await db.exec(fs.readFileSync(new URL('./assisted_employee_contracts.sql', import.meta.url),'utf8'));
  console.log('Assisted contract flow passed: unregistered employee, validation, identity matching, join, terms and idempotency.');
  const actual=(await db.query("select table_name,column_name,udt_name,is_nullable from information_schema.columns where table_schema='public' order by table_name,ordinal_position")).rows;
  const expected=JSON.parse(fs.readFileSync(new URL('../../docs/backend/schema.json', import.meta.url),'utf8')).columns.map(({table_name,column_name,udt_name,is_nullable})=>({table_name,column_name,udt_name,is_nullable}));
  assert.deepStrictEqual(actual,expected);
  const fks=(await db.query("select count(*)::int as count from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype='f'")).rows[0].count;
  assert.strictEqual(fks,19);
  console.log(`Validated complete application DDL: ${actual.length} columns match live schema; ${fks} foreign keys. pgcrypto runtime excluded (not available in PGlite).`);
 }finally{await db.close()}
});
