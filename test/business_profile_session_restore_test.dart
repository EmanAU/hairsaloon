import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
import 'package:hairsaloon/src/features/auth/data/repositories/local_auth_repository.dart';
import 'package:hairsaloon/src/features/business_profile/data/repositories/shared_prefs_business_profile_repository.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sample = BusinessProfile(
    businessName: 'Cut & Co',
    phoneNumber: '+923001234567',
    businessType: 'Barber',
    city: 'Lahore',
    area: 'Gulberg',
    address: 'Gulberg, Lahore',
  );

  test('legacy profile migrates after session exists even if migrate ran first',
      () async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsBusinessProfileRepository.storageKey:
          '{"businessName":"Cut & Co","phoneNumber":"+923001234567",'
          '"businessType":"Barber","city":"Lahore","area":"Gulberg",'
          '"address":"Gulberg, Lahore"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final profiles = SharedPrefsBusinessProfileRepository(prefs: prefs);

    // First boot with no session must not permanently discard legacy data.
    await profiles.migrateLegacyProfile();
    expect(
      prefs.getString(SharedPrefsBusinessProfileRepository.storageKey),
      isNotNull,
    );
    expect(await profiles.getProfile(), isNull);

    final session = LocalAuthSessionDataSource(prefs: prefs);
    final auth = LocalAuthRepository(prefs: prefs, session: session);
    await auth.registerUser(
      name: 'Owner',
      phone: '+923001234567',
      password: 'secret1',
    );

    await profiles.migrateLegacyProfile();
    final restored = await profiles.getProfile();
    expect(restored?.businessName, 'Cut & Co');
    expect(
      prefs.getString(SharedPrefsBusinessProfileRepository.storageKey),
      isNull,
    );
  });

  test('getProfile recovers unscoped legacy without explicit migrate', () async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsBusinessProfileRepository.storageKey:
          '{"businessName":"Cut & Co","phoneNumber":"+923001234567",'
          '"businessType":"Barber","city":"Lahore","area":"Gulberg",'
          '"address":"Gulberg, Lahore"}',
      'profile.scoped.v1': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final session = LocalAuthSessionDataSource(prefs: prefs);
    final auth = LocalAuthRepository(prefs: prefs, session: session);
    final profiles = SharedPrefsBusinessProfileRepository(prefs: prefs);

    await auth.registerUser(
      name: 'Owner',
      phone: '+923001234567',
      password: 'secret1',
    );

    final restored = await profiles.getProfile();
    expect(restored?.businessName, 'Cut & Co');
  });

  test('saved scoped profile survives logout and login restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LocalAuthSessionDataSource(prefs: prefs);
    final auth = LocalAuthRepository(prefs: prefs, session: session);
    final profiles = SharedPrefsBusinessProfileRepository(prefs: prefs);

    await auth.registerUser(
      name: 'Owner',
      phone: '+923001234567',
      password: 'secret1',
    );
    await profiles.saveProfile(sample);
    expect((await profiles.getProfile())?.businessName, 'Cut & Co');

    await auth.logout();
    expect(await profiles.getProfile(), isNull);

    await auth.loginWithPhonePassword(
      phone: '+923001234567',
      password: 'secret1',
    );
    expect((await profiles.getProfile())?.businessName, 'Cut & Co');
  });
}
