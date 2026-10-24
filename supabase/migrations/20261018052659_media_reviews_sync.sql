-- Public discovery exposes only the active employment and display name.
create function private.resolve_barber(employee uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select e.business_id from public.business_employees e
  join public.businesses b on b.id=e.business_id and b.is_active
  where auth.uid() is not null and e.id=employee and exists (
    select 1 from public.employee_contracts c where c.employee_id=e.id
    and c.status='accepted' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now()));
$$;
create function public.resolve_barber(employee uuid) returns uuid
language sql stable security invoker set search_path = '' as $$ select private.resolve_barber(employee); $$;
revoke all on function private.resolve_barber(uuid), public.resolve_barber(uuid) from public,anon;
grant execute on function private.resolve_barber(uuid), public.resolve_barber(uuid) to authenticated;

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  employee_id uuid references public.business_employees(id),
  author_id uuid not null default auth.uid() references public.users(id),
  rating smallint not null check (rating between 1 and 5),
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  unique nulls not distinct (business_id,employee_id,author_id)
);
create index reviews_author_idx on public.reviews(author_id);
create index reviews_employee_idx on public.reviews(employee_id);
alter table public.reviews enable row level security;
revoke all on public.reviews from anon,authenticated;
grant select,delete on public.reviews to authenticated;
grant insert(business_id,employee_id,rating,body),update(rating,body) on public.reviews to authenticated;
create policy reviews_read on public.reviews for select to authenticated using (
  author_id=(select auth.uid()) or (select private.is_admin()) or
  exists(select 1 from public.businesses b where b.id=business_id and b.is_active));
create policy reviews_create on public.reviews for insert to authenticated with check (author_id=(select auth.uid()));
create policy reviews_edit on public.reviews for update to authenticated
  using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
create policy reviews_delete on public.reviews for delete to authenticated
  using(author_id=(select auth.uid()) or (select private.is_admin()));
create function private.validate_review() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or new.author_id<>auth.uid() or not exists(
    select 1 from public.businesses b where b.id=new.business_id and b.is_active and b.owner_id<>auth.uid()
  ) or exists(select 1 from public.business_employees e where e.business_id=new.business_id and e.profile_id=auth.uid()) then
    raise exception 'You cannot review your own salon or an inactive salon' using errcode='42501';
  end if;
  if new.employee_id is not null and private.resolve_barber(new.employee_id) is distinct from new.business_id then
    raise exception 'Barber is not currently working at this salon' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function private.validate_review() from public,anon,authenticated;
create trigger validate_review before insert or update on public.reviews for each row execute function private.validate_review();

-- Private buckets: signed URLs remain subject to the same publication rules as services.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('service-media','service-media',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']),
 ('profile-photos','profile-photos',false,5242880,array['image/jpeg','image/png','image/webp']);
create function private.owns_media_path(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.services s
 join public.businesses b on b.id=s.business_id where b.owner_id=auth.uid()
 and split_part(path,'/',1)=b.id::text and split_part(path,'/',2)=s.id::text);
$$;
revoke all on function private.owns_media_path(text) from public,anon;
grant execute on function private.owns_media_path(text) to authenticated;
create policy service_upload on storage.objects for insert to authenticated
 with check(bucket_id='service-media' and private.owns_media_path(name));
create policy service_remove on storage.objects for delete to authenticated
 using(bucket_id='service-media' and private.owns_media_path(name));
create policy service_download on storage.objects for select to authenticated using(
 bucket_id='service-media' and (private.owns_media_path(name) or exists(
 select 1 from public.service_media m where m.storage_path=name)));
create policy profile_upload on storage.objects for insert to authenticated
 with check(bucket_id='profile-photos' and split_part(name,'/',1)=(select auth.uid())::text);
create policy profile_remove on storage.objects for delete to authenticated
 using(bucket_id='profile-photos' and split_part(name,'/',1)=(select auth.uid())::text);
create policy profile_download on storage.objects for select to authenticated
 using(bucket_id='profile-photos' and (split_part(name,'/',1)=(select auth.uid())::text or (select private.is_admin())));
-- Prevent an owner publishing another salon's storage object through their media row.
create function private.validate_media_path() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from public.services s where s.id=new.service_id
 and split_part(new.storage_path,'/',1)=s.business_id::text
 and split_part(new.storage_path,'/',2)=s.id::text) then
 raise exception 'Media path does not match service' using errcode='23514'; end if;
 return new;
end;
$$;
revoke all on function private.validate_media_path() from public,anon,authenticated;
create trigger validate_media_path before insert or update on public.service_media for each row execute function private.validate_media_path();

-- A complete POS snapshot is updated atomically. Competing devices must resolve
-- a version conflict; retries of the same operation never duplicate a write.
create table public.business_snapshots (
 business_id uuid primary key references public.businesses(id),
 revision bigint not null default 1,
 operation_id uuid not null,
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=20971520),
 updated_at timestamptz not null default now()
);
alter table public.business_snapshots enable row level security;
revoke all on public.business_snapshots from anon,authenticated;
grant select on public.business_snapshots to authenticated;
create policy snapshots_read on public.business_snapshots for select to authenticated
 using(private.owns_business(business_id) or (select private.is_admin()));
create function private.sync_business(business uuid, expected_revision bigint, operation uuid, data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare current_row public.business_snapshots;
begin
 if not private.owns_business(business) then raise exception 'Owner required' using errcode='42501'; end if;
 -- Lock the parent even before the first snapshot exists.
 perform 1 from public.businesses where id=business for update;
 select * into current_row from public.business_snapshots where business_id=business;
 if current_row.operation_id=operation then
   if current_row.payload<>data then raise exception 'Operation reused with different data' using errcode='22023'; end if;
   return jsonb_build_object('conflict',false,'revision',current_row.revision);
 end if;
 if coalesce(current_row.revision,0)<>expected_revision then
   return jsonb_build_object('conflict',true,'revision',current_row.revision);
 end if;
 insert into public.business_snapshots(business_id,revision,operation_id,payload)
 values(business,expected_revision+1,operation,data)
 on conflict(business_id) do update set revision=excluded.revision,operation_id=excluded.operation_id,payload=excluded.payload,updated_at=now();
 return jsonb_build_object('conflict',false,'revision',expected_revision+1);
end;
$$;
create function public.sync_business(business uuid, expected_revision bigint, operation uuid, data jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select private.sync_business(business,expected_revision,operation,data); $$;
revoke all on function private.sync_business(uuid,bigint,uuid,jsonb),public.sync_business(uuid,bigint,uuid,jsonb) from public,anon;
grant execute on function private.sync_business(uuid,bigint,uuid,jsonb),public.sync_business(uuid,bigint,uuid,jsonb) to authenticated;

alter table public.profiles add constraint profile_photo_owner check(photo_path is null or split_part(photo_path,'/',1)=user_id::text);
create function private.barber_photo(employee uuid) returns text
language sql stable security definer set search_path='' as $$
 select p.photo_path from public.profiles p join public.business_employees e on e.profile_id=p.user_id
 where e.id=employee and private.resolve_barber(employee) is not null;
$$;
create function public.barber_photo(employee uuid) returns text
language sql stable security invoker set search_path='' as $$ select private.barber_photo(employee); $$;
create function private.public_profile_photo(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles p
 join public.business_employees e on e.profile_id=p.user_id
 where p.photo_path=path and private.resolve_barber(e.id) is not null);
$$;
revoke all on function private.barber_photo(uuid),public.barber_photo(uuid),private.public_profile_photo(text) from public,anon;
grant execute on function private.barber_photo(uuid),public.barber_photo(uuid),private.public_profile_photo(text) to authenticated;
create policy public_barber_photo on storage.objects for select to authenticated
 using(bucket_id='profile-photos' and private.public_profile_photo(name));

alter table public.service_media add column pair_id uuid;
alter table public.service_media add constraint media_pair_kind check(pair_id is null or kind in ('before','after'));
create unique index service_media_pair_idx on public.service_media(service_id,pair_id,kind) where pair_id is not null;
grant insert(pair_id) on public.service_media to authenticated;
