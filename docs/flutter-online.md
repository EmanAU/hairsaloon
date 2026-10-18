# Flutter business and customer apps

Flutter stays in the repository root (`lib/`, `android/`, `pubspec.yaml`).
The Next.js superadmin is an independent project in `web/` with its own packages,
configuration, build and development server. Shared database migrations live in
`supabase/`; neither frontend imports code from the other frontend.

## Android flavors

```sh
flutter run --flavor business
flutter run --flavor customer
```

`business` is the default flavor. `lib/main.dart` selects the audience using
Flutter's `appFlavor`. The business ID remains `com.barbershop.app` to preserve
existing local installations. Customer uses `com.barbershop.app.customer` so both
apps can be installed together. These flavors currently target Android only.

Without Supabase configuration, online sign-in stays unavailable. The business
app can still open the existing offline app. The customer app does not expose
business/offline management screens.

## Connect Supabase later

Copy `config/supabase.example.json` to `config/supabase.local.json`, then fill in
the project URL and publishable API key. Local JSON files are Git-ignored. Never
put a database password, connection string or service-role secret into Flutter.

```sh
flutter run --flavor business --dart-define-from-file=config/supabase.local.json
flutter run --flavor customer --dart-define-from-file=config/supabase.local.json
```

Apply all migrations from `supabase/migrations/`. Enable Google in Supabase Auth
and configure its Google Cloud OAuth callback. Add these mobile redirect URLs to
Supabase Auth's redirect allow list:

- `com.barbershop.app://login-callback`
- `com.barbershop.app.customer://login-callback`

## Included flows

- Google sign-in, ordinary account creation, persisted Supabase sessions and
  account-scoped navigation reset on sign-out/account change.
- Personal profile with CNIC, birth date, mobile number and copyable permanent code.
- Business registration and editing with pending admin approval.
- Salon invite-code generation, employee join requests and owner invitations.
- Daily/fixed/permanent contract proposals, employee acceptance/decline, history,
  seven-day in-app expiry reminders and owner release with a reason.
- Business rate-list creation/editing, descriptions and service visibility.
- Customer salon-name search with pagination, active barber names, service prices
  and descriptions. Private identity fields never enter the customer directory.

The online implementation is in `lib/src/online/`: domain models/repository
contract, Supabase data implementation, session state and presentation screens.
Screens do not make Supabase calls directly.

## QR, media and reviews

Customer QR links use `trimmatrix://salon/<uuid>` or
`trimmatrix://barber/<membership-uuid>`. Owners display these from business details
and the staff list. Android customer deep links open the same page after sign-in.
Inactive barbers do not resolve. The business flavor handles
`trimmatrix://join/<invite-uuid>` separately; scanning fills the code and still
requires Request to join. External scanning requires the matching app installed.

Owners upload photos, videos and paired before/after results from a saved service's
edit page. Personal profiles accept photos after registration. Only an actively
employed barber's photo is available to customers; CNIC, DOB and private profile
codes remain protected. Private Storage uses one-hour signed URLs; Refresh media
renews them. JPG/PNG/WebP and MP4/MOV are supported (profile 5 MB, media 50 MB).

Customers can review a salon or barber and edit/delete their own review. One review
per customer/target is enforced. Owners and members cannot review their own salon;
visits are not represented as verified. Superadmin can remove reviews in `web/`.

## Offline / online workspace

Open a business, then Offline / online business workspace. Each account/business
has isolated Hive boxes for bills, contacts, local staff, expenses, payouts,
services, categories and settings. First online login caches account/business
details so the same signed-in account can reopen without internet. OAuth, joins,
contracts, public catalog edits, reviews and uploads require internet.

Sync runs every 30 seconds while the workspace screen is open, on entry/exit and
via Sync now. Writes persist locally first. A durable operation journal retries
lost responses without duplicate writes. Revision conflicts stop sync and offer
Keep this device / Use cloud. Both versions are retained in the local sync journal
before resolution. Cloud changes load only while POS is closed to keep stores
consistent. Sync uses complete snapshots (19 MB app / 20 MB database limit), not
record-level merging or OS background execution.

The legacy offline app remains separate; existing device data is not automatically
imported into a cloud salon. The public catalog and employment contracts are
managed through their online screens. Local POS staff/rate-list data does not
authorize cloud contracts. Push/SMS are intentionally excluded; expiry reminders
remain visible in the apps and portal.

## Checks

```sh
flutter test --no-pub test/online
dart analyze lib/src/online lib/main.dart test/online
```

Live OAuth/deep-link round trips and Supabase network integration need a configured
project and device. Mocked widget tests do not verify Google or the live backend.
