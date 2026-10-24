# TrimMatrix code handoff — 25 October 2026

## Delivery scope

The user requested code and testing only; final APK builds were stopped.
Business and Customer are separate Android flavors. The Business app also
contains the employee experience.

Both apps connect directly to the existing hosted Supabase project. No laptop,
Flutter terminal, Node server, or local database needs to stay running for the
mobile backend. Internet is required for sign-in and online operations; cached
business work can continue offline and synchronize when connectivity returns.

## Backend status

The earlier chat applied the latest assisted-employee-contract and employee-work-history
migrations. On 25 October this review independently verified the live
`employee_work_history()` RPC, contract validation trigger, authenticated-only
execution and owner/admin snapshot policy. Migration history also confirms all
latest entries through `20261025024500` (employee snapshot privacy).
No new database migration was needed
for the fixes in this review. Do not rerun the full bootstrap SQL on the existing
project. SQL in `docs/backend/trim-matrix-full-backend.sql` is a fresh-project
bootstrap; `supabase/migrations/` contains versioned updates.

## Commands you may need

From the repository root, rebuild either mobile app:

```powershell
flutter pub get
flutter build apk --release --flavor business
flutter build apk --release --flavor customer
```

Flutter outputs are `build/app/outputs/flutter-apk/app-business-release.apk` and
`build/app/outputs/flutter-apk/app-customer-release.apk`.

Only if you want to run the separate admin website locally:

```powershell
cd web
npm ci
npm run dev
```

Open http://localhost:3000. Keep the existing `web/.env.local` configuration.
This server is for the admin website; stopping it does not stop the mobile backend.
For a production admin build, use `npm run build` then `npm start` in `web`.

## Repeat the checks

```powershell
flutter analyze --no-pub
flutter test --no-pub
cd web
npm run test:db
npm run test:admin
npm run typecheck
```

Database tests include migration/RLS behavior, invite identity, private photo
access, employee lifecycle, pre-login work, contract materialization and settlement
history. PGlite does not support pgcrypto, so manager PIN cryptography is excluded
from that local harness. Google OAuth, physical QR camera scanning and real
multi-account network round trips require device testing; mocked tests do not
prove those external services.

## Signing

The existing Android release configuration uses this machine's debug signing key.
Builds made with the commands above are for direct installation, not Play Store
production-signed packages. Keep the same signing key for updates. A Play Store release needs a
separate upload-key configuration and matching OAuth certificate registration.

## Verification results

- 144 core Flutter tests passed (`build/final-check/core-final.log`).
- Six complete portrait walkthrough sizes passed across the final runs: 600, 800,
  960 tablet widths and 320, 390, 430 mobile widths. Five passed together in
  `portrait-final.log`; the 320-width scroll-finder correction passed in
  `compact-final.log`. The earlier failed attempt is retained in the first log.
- 26 database tests and 7 admin tests passed; admin TypeScript checks passed.
- Dart analyzer: no issues. Business/customer/employee tablet screenshots were
  visually reviewed using Flutter-rendered fixtures.
- Live backend migration history is current through `20261025024500`.

Code fixes: restore pending join-request badge polling; save stable employee IDs
in mobile bills; reuse customer identities across local/international phone
formats while preserving legacy keys and partial searches; guard asynchronous
service navigation. The test suite now follows current account defaults, photo
normalization, owner-managed contracts, menu routes and tablet checkout.
