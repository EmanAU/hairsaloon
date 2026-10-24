import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
import 'package:hairsaloon/src/features/auth/data/repositories/local_auth_repository.dart';
import 'package:hairsaloon/src/features/business_profile/data/repositories/shared_prefs_business_profile_repository.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/settings/data/repositories/hive_settings_repository.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/features/expenses/data/repositories/hive_expenses_repository.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'business profiles remain with their accounts across logout and restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LocalAuthSessionDataSource(prefs: prefs);
      final auth = LocalAuthRepository(prefs: prefs, session: session);
      final profiles = SharedPrefsBusinessProfileRepository(prefs: prefs);
      await profiles.migrateLegacyProfile();
      await auth.registerUser(
        name: 'A',
        phone: '03001234567',
        password: 'secret1',
      );
      await profiles.saveProfile(
        const BusinessProfile(
          businessName: 'Business A',
          phoneNumber: '03001234567',
          businessType: 'Salon',
          city: 'City',
          area: 'Area',
          address: 'Address',
        ),
      );
      await auth.logout();
      expect(await profiles.getProfile(), isNull);
      await expectLater(
        auth.registerUser(
          name: 'Duplicate',
          phone: '+92 300 1234567',
          password: 'secret2',
        ),
        throwsStateError,
      );
      await auth.registerUser(
        name: 'B',
        phone: '+923001234568',
        password: 'secret2',
      );
      expect(await profiles.getProfile(), isNull);
      await profiles.saveProfile(
        const BusinessProfile(
          businessName: 'Business B',
          phoneNumber: '03001234568',
          businessType: 'Salon',
          city: 'City',
          area: 'Area',
          address: 'Address',
        ),
      );
      await auth.logout();
      await auth.loginWithPhonePassword(
        phone: '00923001234567',
        password: 'secret1',
      );
      expect(
        (await SharedPrefsBusinessProfileRepository(
          prefs: prefs,
        ).getProfile())!.businessName,
        'Business A',
      );
    },
  );

  test(
    'named accounts persist per user; unpaid methods clear and payment is recorded',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'account_payments',
      );
      Hive.init(directory.path);
      final settingsBox = await Hive.openBox<dynamic>('settings_test');
      final expenseBox = await Hive.openBox<Map>('expenses_test');
      var owner = 'A';
      final settings = SettingsStore(
        repository: HiveSettingsRepository(
          box: settingsBox,
          accountId: () => owner,
        ),
      );
      final expenses = ExpensesStore(
        repository: HiveExpensesRepository(box: expenseBox),
      );
      try {
        await settings.savePaymentAccount(
          method: 'EasyPaisa',
          holder: 'Abdullah',
        );
        final method = settings.customPaymentAccounts.single;
        expect(method, 'EasyPaisa — Abdullah');
        await expectLater(
          settings.savePaymentAccount(method: 'easypaisa', holder: 'abdullah'),
          throwsArgumentError,
        );
        owner = 'B';
        expect(settings.customPaymentAccounts, isEmpty);
        expect(settings.paymentAccounts, SettingsStore.defaultPaymentAccounts);
        owner = 'A';
        expect(settings.paymentMethods, contains(method));
        final now = DateTime.now();
        await expenses.add(
          ExpenseItem(
            id: 'e',
            date: now,
            employeeName: 'Ali',
            amount: 200,
            status: 'Unpaid',
            paymentType: 'Cash',
            expenseType: 'Supplies',
            quantity: 1,
            description: null,
            createdAt: now,
          ),
        );
        expect(expenses.items.single.paymentType, isEmpty);
        await expenses.markAsPaid('e', paymentType: method);
        expect(expenses.items.single.isPaid, isTrue);
        expect(expenses.items.single.paymentType, method);
        await settings.removePaymentAccount(method);
        expect(expenses.items.single.paymentType, method);
        await expenses.markAsUnpaid('e');
        expect(expenses.items.single.paymentType, isEmpty);
        expenses.reload();
        expect(expenses.items.single.paymentType, isEmpty);
      } finally {
        settings.dispose();
        expenses.dispose();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
