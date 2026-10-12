# Business COMB

Offline Flutter salon management app. Registration and phone/password login use accounts saved on this device; no SMS verification or cloud services are required.

Bills, customers, employees, services, categories, expenses and settings persist in Hive. Business profile and local accounts/session persist in SharedPreferences. Logout preserves business data and profile. Accounts share the single salon workspace on this device.

Previously cloud-only accounts must register locally. Existing Hive and local business profile data remain available. Cloud-only records are not downloaded automatically.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
