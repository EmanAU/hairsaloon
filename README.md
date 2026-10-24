# TrimMatrix

## Online business and customer flavors

Flutter and the Next.js admin portal are separate projects in this repository.
Run `flutter run --flavor business` or `flutter run --flavor customer` from the
root. The business flavor includes an entry to the existing offline app.
See [Flutter setup](docs/flutter-online.md), [admin setup](web/README.md), and
[backend setup](supabase/README.md). The existing Supabase project is configured in the Flutter bootstrap.
See [release handoff](docs/final-release.md) for code verification and backend instructions.

## Existing offline workspace

Android-only Flutter salon management app with local storage. Registration and phone/password login use accounts saved on this device; no SMS verification or cloud services are required.

Bills, customers, employees, services, categories, expenses and settings persist in Hive. Business profile and local accounts/session persist in SharedPreferences. Logout preserves business data and profile. Accounts share the single salon workspace on this device.

Previously cloud-only accounts must register locally. Existing Hive and local business profile data remain available. Cloud-only records are not downloaded automatically.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
