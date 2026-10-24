-- Employee dashboards now use the scoped work-history RPC. Full POS payloads
-- (other staff records, expenses, settings) remain owner/manager/admin only.
alter policy snapshots_read on public.business_snapshots
using(private.owns_business(business_id) or (select private.is_admin()));
