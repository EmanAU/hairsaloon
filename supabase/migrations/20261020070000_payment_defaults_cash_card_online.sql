-- Payment account defaults: Cash, Card, Online only.
-- Remove JazzCash / Easy from the catalog and from seeded business lists.

delete from public.default_payment_accounts
where label in ('Easy — Business', 'JazzCash — Business');

insert into public.default_payment_accounts(label, sort_order)
select * from (values
  ('Cash — Counter', 1),
  ('Card — POS', 2),
  ('Online — Bank transfer', 3)
) as v(label, sort_order)
on conflict (label) do update set sort_order = excluded.sort_order;

-- Drop the old defaults from businesses that already received them.
update public.businesses
set payment_accounts = coalesce((
  select array_agg(x order by ord)
  from unnest(payment_accounts) with ordinality as t(x, ord)
  where x not in ('Easy — Business', 'JazzCash — Business')
), '{}'::text[])
where payment_accounts && array['Easy — Business', 'JazzCash — Business']::text[];
