-- Rich customer-view body for services (Flutter Quill Delta JSON).
alter table public.services
  add column if not exists content_json jsonb not null default '[]'::jsonb;
