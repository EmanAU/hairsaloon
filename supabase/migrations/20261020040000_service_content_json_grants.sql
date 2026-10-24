-- Allow owners to persist Quill customer-view JSON on services.
grant insert (
  business_id, name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;

grant update (
  name, category, subcategory, gender, age_group,
  description, price, is_active, content_json
) on public.services to authenticated;
