# TrimMatrix superadmin

Next.js + Supabase portal. No separate NestJS server or service-role key is used.
The database validates administrator access on every privileged operation.

## Run locally

1. Run `npm ci` in this directory.
2. Copy `.env.example` to `.env.local` and fill in the Supabase project URL,
   publishable key and portal `SITE_URL`.
3. Apply the migrations in `../supabase/` to the intended project.
4. Create the password admin (one-time) in Supabase Auth:
   - Email: value of `ADMIN_EMAIL` (default `yesiamrana@trimmatrix.admin`)
   - Password: value of `ADMIN_PASSWORD` (default `12345678`)
   - Then set that user’s `public.users.role` to `superadmin`
5. Optionally configure Google in Supabase Auth and allow
   `<SITE_URL>/auth/callback` for OAuth sign-in.
6. Run `npm run dev` and open http://localhost:3000.

### Default password credentials

| Field    | Default                         |
|----------|---------------------------------|
| Username | `yesiamrana`                    |
| Password | `12345678`                      |
| Email    | `yesiamrana@trimmatrix.admin`   |

Override with `ADMIN_USERNAME`, `ADMIN_PASSWORD`, and `ADMIN_EMAIL` in
`.env.local`. The form username/password must match the env pair; Auth then
signs in with `ADMIN_EMAIL`.

Without configuration, the portal renders a setup/sign-in page. It does not show
fake administrative records. Google sign-in creates an ordinary `users` record;
only an explicitly promoted superadmin can open the dashboard.

## Included

- Password login (primary) and Google OAuth (secondary).
- Server-side superadmin checks on pages and actions, plus database RLS.
- Paginated business/user/contract lists and business/profile detail pages.
- Business activation/deactivation with reviewer identity and timestamp.
- Contract history, daily/fixed/permanent terms and early release with a reason.
- In-app reminders for accepted contracts ending within seven days.
- Customer review moderation with superadmin-only deletion.
- Light-green professional admin UI (sage canvas, lime accents, black text).

## Checks

```sh
npm run test:db
npm run typecheck
```

The database tests execute the actual migrations in PGlite with `btree_gist`.
Supabase Auth identities, roles and Storage metadata are stubbed. A connected project
is still needed to verify real OAuth, PostgREST, Storage and multi-session behavior.

Backend setup, contract semantics and mobile integration are documented in
`../supabase/README.md`. Dependencies are pinned and the lockfile is tracked.
