-- Explicitly qualify the outer storage object: businesses also has a name column.
alter policy business_photo_upload on storage.objects
with check (bucket_id = 'business-photos' and exists (
  select 1 from public.businesses b
  where b.id::text = split_part(storage.objects.name, '/', 1)
    and b.owner_id = (select auth.uid())
));

alter policy business_photo_remove on storage.objects
using (bucket_id = 'business-photos' and exists (
  select 1 from public.businesses b
  where b.id::text = split_part(storage.objects.name, '/', 1)
    and b.owner_id = (select auth.uid())
));

alter policy business_photo_read on storage.objects
using (bucket_id = 'business-photos' and exists (
  select 1 from public.businesses b
  where b.id::text = split_part(storage.objects.name, '/', 1)
    and (b.is_active or b.owner_id = (select auth.uid()) or (select private.is_admin()))
));
