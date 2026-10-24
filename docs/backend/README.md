# TrimMatrix backend ERD

Schema checked against the linked live PostgreSQL catalog on 24 October 2026. No user records are included.

## Files

- `trim-matrix-erd.png`: shareable diagram.
- `trim-matrix-erd.svg`: scalable diagram; zoom for field labels.
- `trim-matrix-erd.mmd`: editable Mermaid ERD source.
- `schema.json`: complete public column and constraint metadata.

The diagram shows primary keys, foreign keys and selected business fields. This document lists all columns. `nullable` means a relationship or value is optional. Crow's feet indicate many; a circle indicates zero is allowed. Composite foreign keys are shown as one relationship.

## Implementation notes

- `auth.users` is Supabase-managed authentication. `public.users` holds application identity and role; `profiles` holds personal phone, CNIC and photo. The ERD shows only the authentication ID, not Supabase internal auth tables.
- `businesses.owner_id` identifies the owner. Salon phone/logo are separate from personal profile phone/photo. `is_active` records approval; `reviewed_by` links the reviewing user.
- `business_employees` is membership between a business and a personal profile. `is_manager` is an additional membership flag, not a separate user or manager table. Never return `manager_pin_hash` to clients.
- `employee_contracts` has a composite FK `(employee_id, profile_id)` to `business_employees(id, profile_id)`. It does not have an independent FK from `profile_id` to `profiles`.
- `business_invites` stores each shop's joining code. `employee_invites` stores owner-issued CNIC/email invitations; these are distinct flows. Invitations do not have a direct FK to a profile.
- `reviews.employee_id` is optional: null means a salon-level review, populated means a specific employee review. Uniqueness is `(business_id, employee_id, author_id)` with NULLS NOT DISTINCT.
- Local POS collections (`bills`, `contacts`, `employees`, `expenses`, `payouts`, `services`, `categories`) plus `phones` and `settings` are synchronized inside `business_snapshots.payload` JSONB. These are not separate PostgreSQL tables. Online `services` and `business_employees` are separate relational entities.
- `service_media.storage_path`, `profiles.photo_path` and `businesses.logo_path` reference Storage object paths, not database foreign keys. Buckets: `service-media`, `profile-photos`, `business-photos` (private; signed URLs). `service_media.pair_id` groups media; it is not a foreign key.
- `default_services`, `default_expense_types`, and `default_payment_accounts` are seed catalogs. There are no direct foreign keys from the copied business settings/services back to these catalogs.
- `contract_reminders` is a view, not a base table. It is omitted from the ERD.
- RLS, grants, RPC logic, triggers and partial/exclusion indexes also govern behavior; the ERD alone is not an authorization specification. Refer to `supabase/migrations/`.

## Complete column dictionary

### public.business_employees

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `business_id`: `uuid` (required).
- `profile_id`: `uuid` (required).
- `requested_by`: `uuid` (required).
- `created_at`: `timestamptz` (required) — default: `now()`.
- `join_status`: `text` (required) — default: `'pending'::text`.
- `join_reviewed_at`: `timestamptz` (nullable).
- `join_reviewed_by`: `uuid` (nullable).
- `is_manager`: `bool` (required) — default: `false`.
- `manager_pin_hash`: `text` (nullable).

Constraints:

- `CHECK ((join_status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text])))`
- `FOREIGN KEY (business_id) REFERENCES businesses(id)`
- `FOREIGN KEY (join_reviewed_by) REFERENCES users(id)`
- `FOREIGN KEY (profile_id) REFERENCES profiles(user_id)`
- `FOREIGN KEY (requested_by) REFERENCES users(id)`
- `PRIMARY KEY (id)`
- `UNIQUE (business_id, profile_id)`
- `UNIQUE (id, profile_id)`

### public.business_invites

- `business_id`: `uuid` (required).
- `code`: `uuid` (required) — default: `gen_random_uuid()`.

Constraints:

- `FOREIGN KEY (business_id) REFERENCES businesses(id)`
- `PRIMARY KEY (business_id)`
- `UNIQUE (code)`

### public.business_snapshots

- `business_id`: `uuid` (required).
- `revision`: `int8` (required) — default: `1`.
- `operation_id`: `uuid` (required).
- `payload`: `jsonb` (required).
- `updated_at`: `timestamptz` (required) — default: `now()`.

Constraints:

- `CHECK (((jsonb_typeof(payload) = 'object'::text) AND (octet_length((payload)::text) <= 20971520)))`
- `FOREIGN KEY (business_id) REFERENCES businesses(id)`
- `PRIMARY KEY (business_id)`

### public.businesses

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `owner_id`: `uuid` (required).
- `name`: `text` (required).
- `phone`: `text` (required).
- `business_type`: `text` (required).
- `city`: `text` (required).
- `area`: `text` (required).
- `address`: `text` (required).
- `logo_path`: `text` (nullable).
- `is_active`: `bool` (required) — default: `false`.
- `reviewed_by`: `uuid` (nullable).
- `reviewed_at`: `timestamptz` (nullable).
- `created_at`: `timestamptz` (required) — default: `now()`.
- `tax_rate`: `numeric` (required) — default: `17`.
- `currency_code`: `text` (required) — default: `'PKR'::text`.
- `expense_types`: `_text` (required) — default: `'{}'::text[]`.
- `payment_accounts`: `_text` (required) — default: `'{}'::text[]`.

Constraints:

- `CHECK (((logo_path IS NULL) OR (split_part(logo_path, '/'::text, 1) = (id)::text)))`
- `CHECK ((currency_code ~ '^[A-Z]{3}$'::text))`
- `CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 160)))`
- `CHECK ((phone ~ '^\+?[0-9]{10,15}$'::text))`
- `CHECK (((tax_rate >= (0)::numeric) AND (tax_rate <= (100)::numeric)))`
- `FOREIGN KEY (owner_id) REFERENCES users(id)`
- `FOREIGN KEY (reviewed_by) REFERENCES users(id)`
- `PRIMARY KEY (id)`

### public.default_expense_types

- `name`: `text` (required).
- `sort_order`: `int4` (required) — default: `0`.

Constraints:

- `CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 80)))`
- `PRIMARY KEY (name)`

### public.default_payment_accounts

- `label`: `text` (required).
- `sort_order`: `int4` (required) — default: `0`.

Constraints:

- `CHECK (((length(TRIM(BOTH FROM label)) >= 1) AND (length(TRIM(BOTH FROM label)) <= 120)))`
- `PRIMARY KEY (label)`

### public.default_services

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `name`: `text` (required).
- `category`: `text` (required).
- `description`: `text` (required) — default: `''::text`.
- `price`: `numeric` (required).
- `sort_order`: `int4` (required) — default: `0`.
- `subcategory`: `text` (required) — default: `''::text`.
- `gender`: `text` (required) — default: `''::text`.
- `age_group`: `text` (required) — default: `''::text`.

Constraints:

- `CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 160)))`
- `CHECK ((price >= (0)::numeric))`
- `PRIMARY KEY (id)`

### public.employee_contracts

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `employee_id`: `uuid` (required).
- `profile_id`: `uuid` (required).
- `kind`: `text` (required).
- `starts_at`: `timestamptz` (required).
- `ends_at`: `timestamptz` (nullable).
- `salary`: `numeric` (required) — default: `0`.
- `commission_percent`: `numeric` (required) — default: `0`.
- `terms`: `text` (required) — default: `''::text`.
- `status`: `text` (required) — default: `'draft'::text`.
- `accepted_at`: `timestamptz` (nullable).
- `released_at`: `timestamptz` (nullable).
- `released_by`: `uuid` (nullable).
- `release_reason`: `text` (nullable).
- `created_at`: `timestamptz` (required) — default: `now()`.

Constraints:

- `CHECK (((ends_at IS NULL) OR (ends_at > starts_at)))`
- `CHECK ((((kind = 'permanent'::text) AND (ends_at IS NULL)) OR ((kind <> 'permanent'::text) AND (ends_at IS NOT NULL))))`
- `CHECK (((kind <> 'daily'::text) OR (ends_at <= (starts_at + '24:00:00'::interval))))`
- `CHECK (((status = ANY (ARRAY['accepted'::text, 'released'::text])) = (accepted_at IS NOT NULL)))`
- `CHECK (((status = 'released'::text) = (released_at IS NOT NULL)))`
- `CHECK (((status <> 'released'::text) OR ((released_by IS NOT NULL) AND (length(TRIM(BOTH FROM release_reason)) > 0))))`
- `CHECK (((commission_percent >= (0)::numeric) AND (commission_percent <= (100)::numeric)))`
- `CHECK ((kind = ANY (ARRAY['daily'::text, 'fixed'::text, 'permanent'::text])))`
- `CHECK ((salary >= (0)::numeric))`
- `CHECK ((status = ANY (ARRAY['draft'::text, 'accepted'::text, 'declined'::text, 'released'::text])))`
- `FOREIGN KEY (employee_id, profile_id) REFERENCES business_employees(id, profile_id)`
- `FOREIGN KEY (released_by) REFERENCES users(id)`
- `PRIMARY KEY (id)`
- `EXCLUDE USING gist (profile_id WITH =, tstzrange(starts_at,
CASE
    WHEN ((ends_at IS NULL) AND (released_at IS NULL)) THEN NULL::timestamp with time zone
    ELSE GREATEST(starts_at, LEAST(ends_at, released_at))
END, '[)'::text) WITH &&) WHERE ((status = ANY (ARRAY['accepted'::text, 'released'::text])))`

### public.employee_invites

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `business_id`: `uuid` (required).
- `cnic`: `text` (required).
- `phone`: `text` (required).
- `email`: `text` (required).
- `display_name`: `text` (required) — default: `''::text`.
- `invited_by`: `uuid` (required).
- `status`: `text` (required) — default: `'pending'::text`.
- `created_at`: `timestamptz` (required) — default: `now()`.
- `responded_at`: `timestamptz` (nullable).

Constraints:

- `CHECK ((cnic ~ '^[0-9]{13}$'::text))`
- `CHECK (((length(TRIM(BOTH FROM email)) >= 3) AND (length(TRIM(BOTH FROM email)) <= 254)))`
- `CHECK ((phone ~ '^\+?[0-9]{10,15}$'::text))`
- `CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'cancelled'::text])))`
- `FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`
- `FOREIGN KEY (invited_by) REFERENCES users(id)`
- `PRIMARY KEY (id)`
- `UNIQUE (business_id, cnic)`

### public.profiles

- `user_id`: `uuid` (required).
- `code`: `uuid` (required) — default: `gen_random_uuid()`.
- `cnic`: `text` (nullable).
- `date_of_birth`: `date` (nullable).
- `phone`: `text` (required).
- `photo_path`: `text` (nullable).
- `created_at`: `timestamptz` (required) — default: `now()`.
- `work_started_on`: `date` (nullable).

Constraints:

- `CHECK (((photo_path IS NULL) OR (split_part(photo_path, '/'::text, 1) = (user_id)::text)))`
- `CHECK (((work_started_on IS NULL) OR ((work_started_on <= ((now() AT TIME ZONE 'Asia/Karachi'::text))::date) AND ((date_of_birth IS NULL) OR (work_started_on >= date_of_birth)))))`
- `CHECK ((cnic ~ '^[0-9]{13}$'::text))`
- `CHECK ((phone ~ '^\+?[0-9]{10,15}$'::text))`
- `FOREIGN KEY (user_id) REFERENCES users(id)`
- `PRIMARY KEY (user_id)`
- `UNIQUE (cnic)`
- `UNIQUE (code)`

### public.reviews

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `business_id`: `uuid` (required).
- `employee_id`: `uuid` (nullable).
- `author_id`: `uuid` (required) — default: `auth.uid()`.
- `rating`: `int2` (required).
- `body`: `text` (required).
- `created_at`: `timestamptz` (required) — default: `now()`.

Constraints:

- `CHECK (((length(TRIM(BOTH FROM body)) >= 1) AND (length(TRIM(BOTH FROM body)) <= 2000)))`
- `CHECK (((rating >= 1) AND (rating <= 5)))`
- `FOREIGN KEY (author_id) REFERENCES users(id)`
- `FOREIGN KEY (business_id) REFERENCES businesses(id)`
- `FOREIGN KEY (employee_id) REFERENCES business_employees(id)`
- `PRIMARY KEY (id)`
- `UNIQUE NULLS NOT DISTINCT (business_id, employee_id, author_id)`

### public.service_media

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `service_id`: `uuid` (required).
- `kind`: `text` (required).
- `storage_path`: `text` (required).
- `position`: `int4` (required) — default: `0`.
- `pair_id`: `uuid` (nullable).

Constraints:

- `CHECK (((pair_id IS NULL) OR (kind = ANY (ARRAY['before'::text, 'after'::text]))))`
- `CHECK ((kind = ANY (ARRAY['photo'::text, 'video'::text, 'before'::text, 'after'::text])))`
- `CHECK (("position" >= 0))`
- `FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE`
- `PRIMARY KEY (id)`

### public.services

- `id`: `uuid` (required) — default: `gen_random_uuid()`.
- `business_id`: `uuid` (required).
- `name`: `text` (required).
- `category`: `text` (required).
- `subcategory`: `text` (required) — default: `''::text`.
- `gender`: `text` (required) — default: `''::text`.
- `age_group`: `text` (required) — default: `''::text`.
- `description`: `text` (required) — default: `''::text`.
- `price`: `numeric` (required).
- `is_active`: `bool` (required) — default: `true`.
- `created_at`: `timestamptz` (required) — default: `now()`.
- `content_json`: `jsonb` (required) — default: `'[]'::jsonb`.

Constraints:

- `CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 160)))`
- `CHECK ((price >= (0)::numeric))`
- `FOREIGN KEY (business_id) REFERENCES businesses(id)`
- `PRIMARY KEY (id)`

### public.users

- `id`: `uuid` (required).
- `display_name`: `text` (required).
- `role`: `text` (required) — default: `'user'::text`.
- `created_at`: `timestamptz` (required) — default: `now()`.

Constraints:

- `CHECK (((length(TRIM(BOTH FROM display_name)) >= 1) AND (length(TRIM(BOTH FROM display_name)) <= 120)))`
- `CHECK ((role = ANY (ARRAY['user'::text, 'superadmin'::text])))`
- `FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE`
- `PRIMARY KEY (id)`

## Employee onboarding and leaving

Owners can create complete employee records on the device. These synchronize to
`employee_invites.employee_data`; `local_employee_id` preserves the POS employee
identity when a verified Google account accepts the invitation. The JSON includes
personal details and an optional employee photo; it is restricted to the owner and
matching invite recipient. Google email identifies the recipient, with CNIC checked
against any existing profile. Existing personal photos and contact details are preserved.

`business_employees.is_active` records the owner's active/inactive switch separately
from `join_status`. Leaving sets status to `left`, deactivates employment, revokes
manager access, and releases accepted contracts. Accepted employees cannot create a
business until they leave. Code/QR **Join a salon** remains available for self-service
joining, including a fresh request after leaving. Owner approval activates that request.
The latest columns and constraints are in `schema.json` and the full bootstrap SQL.

## View

`public.contract_reminders`: `id`, `employee_id`, `profile_id`, `ends_at`.

Profile work-start validation uses the Asia/Karachi calendar date, including the hours after Pakistan midnight while UTC is still on the previous date. Birth and work-start dates may be shared across users; CNIC remains unique.
