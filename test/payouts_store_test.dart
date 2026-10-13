import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/finance/data/repositories/hive_payouts_repository.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';

void main() {
  test(
    'partial, repeated and bonus payments persist without overwriting history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'settlement_test',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<Map>('payout_test');
      const employee = EmployeeItem(
        id: 'e1',
        firstName: 'Ali',
        lastName: '',
        phoneNumber: '',
        cnicNumber: '',
        homeAddress: '',
        isActive: true,
      );
      final date = DateTime(2026, 10, 14);
      final day = EmployeeDayIncome(
        date: date,
        sales: 2000,
        earning: 2000,
        expenseCut: 0,
        payableAmount: 2000,
        payout: null,
      );
      final repository = HivePayoutsRepository(box: box);
      final store = PayoutsStore(repository: repository);
      try {
        await store.settleDays(employee: employee, days: [day], amount: 400);
        expect(store.payouts.single.amount, 400);
        final key = SalaryPayout.dayKey(employee.id, date);
        expect(store.payoutsById[key]!.incomeAmount, 400);
        await store.settleDays(employee: employee, days: [day], amount: 600);
        expect(store.payouts, hasLength(2));
        expect(store.payoutsById[key]!.incomeAmount, 1000);
        await expectLater(
          store.settleDays(employee: employee, days: [day], amount: 1200),
          throwsStateError,
        );
        expect(store.payouts, hasLength(2));
        await store.settleDays(
          employee: employee,
          days: [day],
          amount: 1200,
          bonusConfirmed: true,
        );
        final reloaded = PayoutsStore(repository: repository);
        expect(reloaded.payouts, hasLength(3));
        expect(reloaded.payoutsById[key]!.amount, 2200);
        expect(reloaded.payoutsById[key]!.incomeAmount, 2000);
        expect(reloaded.payoutsById[key]!.bonusAmount, 200);
        reloaded.dispose();
        await expectLater(
          store.settleDays(employee: employee, days: [day], amount: double.nan),
          throwsArgumentError,
        );
      } finally {
        store.dispose();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
