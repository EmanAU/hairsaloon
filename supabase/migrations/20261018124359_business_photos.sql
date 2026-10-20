insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('business-photos','business-photos',false,2097152,
  array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

alter table public.businesses add constraint business_photo_path
  check (logo_path is null or split_part(logo_path,'/',1)=id::text);

create policy business_photo_upload on storage.objects for insert to authenticated
with check (bucket_id='business-photos' and exists (
  select 1 from public.businesses b where b.id::text=split_part(storage.objects.name,'/',1)
  and b.owner_id=(select auth.uid())
));
create policy business_photo_remove on storage.objects for delete to authenticated
using (bucket_id='business-photos' and exists (
  select 1 from public.businesses b where b.id::text=split_part(storage.objects.name,'/',1)
  and b.owner_id=(select auth.uid())
));
create policy business_photo_read on storage.objects for select to authenticated
using (bucket_id='business-photos' and exists (
  select 1 from public.businesses b where b.id::text=split_part(storage.objects.name,'/',1)
  and (b.is_active or b.owner_id=(select auth.uid()) or (select private.is_admin()))
));
