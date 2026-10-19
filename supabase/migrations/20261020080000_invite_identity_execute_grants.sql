-- Fix: public.invite_employee_by_identity is SECURITY INVOKER and calls private.*.
-- private was revoked from public/anon but never granted to authenticated, so
-- PostgREST returned "permission denied for function invite_employee_by_identity".

grant execute on function
  private.invite_employee_by_identity(uuid, text, text, text, text),
  private.pending_invites_for_me(),
  private.respond_to_employee_invite(uuid, boolean),
  private.set_employee_manager(uuid, boolean, text),
  private.verify_manager_pin(uuid, text),
  private.my_manager_businesses()
to authenticated;
