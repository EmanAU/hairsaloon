# Supabase backend

## Apply and connect later

This is an imperative migration project. Apply all SQL migrations in
filename order using the Supabase CLI after linking the intended project. Use
`supabase db push --help` to inspect the installed CLI before deployment.
No remote database has been connected or modified during development.

For a full local Supabase stack, install a supported container runtime and run
`supabase start` from the repository root. This machine currently has no Docker
command, so local validation uses PGlite PostgreSQL instead.

The Flutter/web clients need the project URL and publishable API key. A database
connection string is for trusted tooling only, never a mobile/browser setting.

## First superadmin

Sign in through the portal once to create the ordinary account. In the trusted
Supabase SQL editor, promote the specific Auth user UUID:

```sql
update public.users set role = 'superadmin' where id = '<AUTH_USER_UUID>';
```

Public registration cannot assign roles. User-editable JWT metadata is never used
for authorization. Review role assignments carefully; every superadmin can read
private profiles and contracts. No default administrator account is seeded.

## Data and workflow

- `users`: one row per Supabase Auth identity, default role `user`.
- `profiles`: private CNIC (13 digits), DOB, mobile number, photo storage path and
  immutable UUID profile code. SIM means mobile number; one phone field avoids
  storing the same value twice.
- `businesses`: owner, details, inactive-by-default approval and review metadata.
- `business_invites`: private UUID joining codes, separate from discoverable salons.
- `business_employees`: a request/membership linking business and profile. This
  alone is not an active employment relationship.
- `employee_contracts`: owner proposal followed by the employee's acceptance.
- `services` / `service_media`: rate list, descriptions and media references.

The owner creates a business invite by inserting its `business_id` into
`business_invites`. QR rendering will encode that same invite value in the app.
`request_join(invite_code)` requests membership; `invite_employee(business,
profile_code)` supports owner-initiated invitations. Both are idempotent.

`propose_contract(employee, contract_kind, starts, ends, basic_salary, commission,
description)` creates a draft. `respond_to_contract(contract, accept)` is callable
only by that employee. Only the business owner or superadmin can call
`release_contract(contract, reason)`. `review_business(business, active)` requires
superadmin access. Public RPCs are invoker wrappers around authorized functions
in the unexposed `private` schema. Definer privileges are required specifically
for protected transitions and private lookups, not general client CRUD.

## Contract semantics

Daily contracts have an explicit interval of at most 24 hours. Fixed contracts
have an end time; permanent contracts have no end time. Store times in UTC and
render them in Asia/Karachi. Adjacent contract periods are allowed; overlaps for
the same employee are rejected by a PostgreSQL exclusion constraint, including
competing transactions. Accepted and released history retains its actual period.

Expiry is derived from time, not a cron-updated status: a completed period no
longer blocks later contracts. Early release truncates the effective period and
records who released it and why. Scheduled contracts can also be released before
they start. Owners cannot alter terms after proposal or accept on an employee's
behalf. Revised proposals are new drafts; the employee can decline old drafts.

`contract_reminders` is an RLS-protected view for end dates within the next seven
days. Currently these are portal reminders, not SMS, email or push notifications.
Permanent contracts have no expiry reminder. External notification delivery has
not been configured.

## Verification

From `web/`, run `npm ci`, `npm run test:db` and `npm run typecheck`.
The tests use actual PostgreSQL SQL, including RLS and GiST exclusion constraints,
through PGlite. Auth identity and Storage metadata are stubbed; live Auth and network
sessions still require integration verification. Run Supabase database advisors
against the configured project before release.

## Flutter integration

The Flutter business/customer flavors now use these tables and RPCs for Google
onboarding, personal profiles, business registration, code-based joining,
contracts, rate-list editing and customer discovery. `business_staff` exposes
names of currently contracted barbers to customers; only owners/admins can see
pending memberships. See `../docs/flutter-online.md` for separate mobile setup.

QR discovery, private media buckets/policies, profile photos, reviews and business
snapshot synchronization are implemented in the final migration. Reviews enforce
author ownership and active target validation. Snapshots are owner-scoped and use
idempotent operations with revision conflicts. See the Flutter guide for limits
and device verification. Push and SMS are excluded. Hosted migrations and real
OAuth/Storage integration still require project configuration.
