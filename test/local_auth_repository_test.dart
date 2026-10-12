import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
import 'package:hairsaloon/src/features/auth/data/repositories/local_auth_repository.dart';

void main() {
  late SharedPreferences prefs;
  late LocalAuthRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = LocalAuthRepository(
      prefs: prefs,
      session: LocalAuthSessionDataSource(prefs: prefs),
    );
  });

  test(
    'local account persists across repository recreation and logout',
    () async {
      final user = await repository.registerUser(
        name: 'Ali',
        phone: '+92 300 1234567',
        password: 'secret123',
      );
      final restored = LocalAuthRepository(
        prefs: prefs,
        session: LocalAuthSessionDataSource(prefs: prefs),
      );
      expect((await restored.getCurrentUser())?.id, user.id);
      await restored.logout();
      expect(await restored.hasSession(), isFalse);
      expect(
        (await restored.loginWithPhonePassword(
          phone: '+923001234567',
          password: 'secret123',
        )).id,
        user.id,
      );
      expect(
        prefs.getString('auth.local_accounts.v1'),
        isNot(contains('secret123')),
      );
    },
  );

  test(
    'duplicate phone and incorrect password fail without creating a session',
    () async {
      await repository.registerUser(
        name: 'Ali',
        phone: '+923001234567',
        password: 'secret123',
      );
      await expectLater(
        repository.registerUser(
          name: 'Other',
          phone: '+92 300 1234567',
          password: 'secret456',
        ),
        throwsStateError,
      );
      await repository.logout();
      await expectLater(
        repository.loginWithPhonePassword(
          phone: '+923001234567',
          password: 'incorrect',
        ),
        throwsStateError,
      );
      expect(await repository.hasSession(), isFalse);
    },
  );

  test('old cloud session without a local account is not accepted', () async {
    await LocalAuthSessionDataSource(prefs: prefs).writeUserId('old-cloud-id');
    expect(await repository.hasSession(), isFalse);
  });
}
