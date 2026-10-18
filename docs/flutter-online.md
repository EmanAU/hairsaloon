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

Both flavors use the project's public Supabase URL and publishable key by default.
`flutter run --debug` starts the business app without extra configuration flags.
The business app can still open the existing offline app. The customer app does
not expose business/offline management screens.

## Override Supabase configuration (optional)

To use a different project, copy `config/supabase.example.json` to
`config/supabase.local.json`, then fill in
the project URL and publishable API key. Local JSON files are Git-ignored. Never
put a database password, connection string or service-role secret into Flutter.

```sh
flutter run --flavor business --dart-define-from-file=config/supabase.local.json
flutter run --flavor customer --dart-define-from-file=config/supabase.local.json
```

Apply all migrations from `supabase/migrations/`. Enable Google in Supabase Auth.

## Native Google login (Android)

Both Flutter flavors use `google_sign_in` to show Google's native account picker,
then pass its ID token to Supabase. Mobile login does not launch browser OAuth.
The Web OAuth client ID is configured by default in `native_google_auth.dart`;
`GOOGLE_WEB_CLIENT_ID` can override it for another environment.

In the same Google Cloud project, register Android OAuth clients for
`com.barbershop.app` and `com.barbershop.app.customer`, with each signing SHA-1
used (debug, release and Play App Signing where applicable). In Supabase's Google
provider settings, include the configured Web OAuth client ID in the allowed
Client IDs. No Google client secret belongs in Flutter. Firebase and
`google-services.json` are not required with this explicit server client ID.

The independent Next.js portal still uses browser OAuth and its existing callback.

## Included flows

- Google sign-in, ordinary account creation, persisted Supabase sessions and
  account-scoped navigation reset on sign-out/account change.
- Personal profile before business setup, with full name, CNIC, birth date, mobile
  number, photo, work start date and copyable permanent code. Experience is calculated
  from the work start date. Incomplete profiles reopen after business-app sign-in.
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
edit page. Personal profile photos can be selected during onboarding. Only an actively
employed barber's photo is available to customers; CNIC, DOB and private profile
codes remain protected. Private Storage uses one-hour signed URLs; Refresh media
renews them. JPG/PNG/WebP and MP4/MOV are supported (profile 2 MB, media 50 MB).

Existing databases must apply `20261018121502_personal_profile_onboarding.sql`
after the earlier migrations. It adds `profiles.work_started_on` and updates the
existing private `profile-photos` bucket to a 2 MB limit. Supabase Auth creates
the user UUID at sign-in; inserting the profile generates its permanent code.

Business registration uses the same ten business types as the offline workspace.
Owners can add/change a business photo (JPG/PNG/WebP, up to 2 MB). Apply
`20261018124359_business_photos.sql` after the earlier migrations to create the
private `business-photos` bucket and its ownership/approval policies. Business
photo paths are stored in the existing `businesses.logo_path` column.

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
