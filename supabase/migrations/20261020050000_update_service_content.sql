-- Persist Quill customer-view JSON even when column grants lag behind.
create or replace function public.update_service_content(
  service uuid,
  content jsonb,
  plain_description text default null
) returns public.services
language plpgsql
security invoker
set search_path = ''
as $$
declare
  row public.services;
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.services s
    where s.id = service and private.owns_business(s.business_id)
  ) then
    raise exception 'Business owner access required' using errcode = '42501';
  end if;

  update public.services s
  set
    content_json = coalesce(content, '[]'::jsonb),
    description = coalesce(nullif(trim(plain_description), ''), s.description)
  where s.id = service
  returning * into row;

  return row;
end;
$$;

revoke all on function public.update_service_content(uuid, jsonb, text) from public, anon;
grant execute on function public.update_service_content(uuid, jsonb, text) to authenticated;

-- Also grant column access for direct updates / inserts.
grant insert (
  business_id, name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;

grant update (
  name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;
