-- Assign a permanent employee joining code in the registration transaction.
create function private.create_business_code() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.business_invites(business_id) values (new.id);
  return new;
end;
$$;
revoke all on function private.create_business_code() from public,anon,authenticated;
create trigger create_business_code after insert on public.businesses
for each row execute function private.create_business_code();

-- Preserve any codes already shared by existing businesses.
insert into public.business_invites(business_id)
select id from public.businesses
on conflict (business_id) do nothing;
