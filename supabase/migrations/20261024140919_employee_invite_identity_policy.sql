-- RLS policies execute with the caller's table privileges. Never reference
-- auth.users directly from an authenticated policy expression.
create or replace function private.invite_matches_current_user(invite_cnic text, invite_email text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.profiles p
    join auth.users u on u.id = p.user_id
    where p.user_id = (select auth.uid())
      and p.cnic = invite_cnic
      and lower(coalesce(u.email, '')) = lower(invite_email)
  );
$$;

revoke all on function private.invite_matches_current_user(text, text) from public, anon;
grant execute on function private.invite_matches_current_user(text, text) to authenticated;

drop policy if exists employee_invites_self_read on public.employee_invites;
create policy employee_invites_self_read on public.employee_invites
for select to authenticated using (
  status = 'pending'
  and (select private.invite_matches_current_user(cnic, email))
);
