import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';

import 'package:hairsaloon/src/online/domain/online_models.dart';

void main() {
  final day = DateTime(2026, 10, 13, 12);
  const employee = EmployeeItem(
    id: 'e1',
    firstName: 'Ali',
    lastName: '',
    phoneNumber: '',
    cnicNumber: '',
    homeAddress: '',
    isActive: true,
    commission: '40',
  );
  final bills = [
    Bill(
      id: 'b1',
      createdAt: day,
      customerName: '',
      customerPhone: '',
      employeeName: 'Ali',
      paymentType: 'Cash',
      lines: const [BillLine(serviceName: 'Cut', price: 1000)],
      subTotal: 1000,
      taxPercent: 0,
      taxAmount: 0,
      grandTotal: 1000,
    ),
  ];
  final expenses = [
    ExpenseItem(
      id: 'x1',
      date: day,
      employeeName: 'Ali',
      amount: 100,
      status: 'Unpaid',
      paymentType: 'Cash',
      expenseType: 'Advance',
      quantity: 1,
      description: null,
      createdAt: day,
    ),
  ];

  test('empty or invalid commission defaults to 0 percent', () {
    expect(FinanceCalculator.commissionPercent(null), 0);
    expect(FinanceCalculator.commissionPercent(''), 0);
    expect(FinanceCalculator.commissionPercent('0'), 0);
    expect(FinanceCalculator.commissionPercent('-5'), 0);
    expect(FinanceCalculator.commissionPercent('10'), 10);
    expect(FinanceCalculator.commissionPercent('10%'), 10);
  });

  for (final discount in [
    (BillDiscountType.none, 0.0, 1170.0),
    (BillDiscountType.amount, 100.0, 1053.0),
    (BillDiscountType.percent, 10.0, 1053.0),
    (BillDiscountType.percent, 100.0, 0.0),
  ]) {
    test(
      'commission excludes tax and shop discount ${discount.$1} ${discount.$2}',
      () {
        final totals = BillTotals.compute(
          subTotal: 1000,
          taxPercent: 17,
          discountType: discount.$1,
          discountValue: discount.$2,
        );
        final bill = Bill.fromJson(
          Bill(
            id: 'discounted',
            createdAt: day,
            customerName: 'Hassan',
            customerPhone: '',
            employeeName: 'Ali',
            paymentType: 'Cash',
            lines: const [BillLine(serviceName: 'Cut', price: 500, qty: 2)],
            subTotal: totals.subTotal,
            taxPercent: 17,
            taxAmount: totals.taxAmount,
            grandTotal: totals.grandTotal,
            discountType: discount.$1,
            discountValue: discount.$2,
            discountAmount: totals.discountAmount,
          ).toJson(),
        );
        final days = FinanceCalculator.employeeDays(
          employee: employee,
          bills: [bill],
          expenses: const [],
          payoutsById: const {},
          include: (_) => true,
        );
        expect(days.single.earning, 400);
        expect(days.single.sales, closeTo(discount.$3, 0.001));
        final job = EmployeeWorkJob(
          id: bill.id,
          createdAt: day,
          customerName: bill.customerName,
          total: bill.grandTotal,
          services: const ['Cut'],
          businessName: 'Salon',
          commissionPercent: 40,
          bill: bill,
        );
        expect(job.earning, 400);
        expect(job.total, closeTo(discount.$3, 0.001));
        expect(job.paymentType, 'Cash');
      },
    );
  }

  test('stable employee id survives renames and separates identical names', () {
    final mine = Bill.fromJson({
      ...bills.single.toJson(),
      'employeeId': employee.id,
      'employeeName': 'Previous name',
    });
    final other = Bill.fromJson({
      ...bills.single.toJson(),
      'id': 'other',
      'employeeId': 'another-person',
    });
    final days = FinanceCalculator.employeeDays(
      employee: employee,
      bills: [mine, other],
      expenses: const [],
      payoutsById: const {},
      include: (_) => true,
    );
    expect(days.single.sales, 1000);
    expect(days.single.earning, 400);
  });

  test('shop expenses never reduce employee commission', () {
    final days = FinanceCalculator.employeeDays(
      employee: employee,
      bills: bills,
      expenses: expenses,
      payoutsById: const {},
      include: (_) => true,
    );
    expect(days, hasLength(1));
    expect(days.single.earning, 400);
    expect(days.single.expenseCut, 0);
    expect(days.single.dueAmount, 400);
  });

  test('settling a day lowers profit by the payout amount', () {
    FinanceTotals totalsWith(List<SalaryPayout> payouts) =>
        FinanceCalculator.totals(
          bills: bills,
          expenses: expenses,
          payouts: payouts,
          anchor: day,
          period: FinancePeriod.daily,
        );

    final before = totalsWith(const []);
    expect(before.profit, 900);

    final payout = SalaryPayout(
      id: SalaryPayout.dayKey(employee.id, day),
      employeeId: employee.id,
      employeeName: employee.fullName,
      workDate: FinanceCalculator.dayOf(day),
      amount: 300,
      settledAt: day,
    );
    final after = totalsWith([payout]);
    expect(after.salaries, 300);
    expect(after.profit, 600);

    final settledDays = FinanceCalculator.employeeDays(
      employee: employee,
      bills: bills,
      expenses: expenses,
      payoutsById: {payout.id: payout},
      include: (_) => true,
    );
    expect(settledDays.single.isSettled, isFalse);
    expect(settledDays.single.dueAmount, 100);
  });
  test(
    'bonus does not pay down future commission and survives serialization',
    () {
      final payout = SalaryPayout(
        id: SalaryPayout.dayKey(employee.id, day),
        employeeId: employee.id,
        employeeName: employee.fullName,
        workDate: day,
        amount: 500,
        bonusAmount: 100,
        settledAt: day,
      );
      final restored = SalaryPayout.fromMap(payout.toMap());
      expect(restored.bonusAmount, 100);
      final days = FinanceCalculator.employeeDays(
        employee: employee,
        bills: [...bills, ...bills],
        expenses: expenses,
        payoutsById: {payout.id: restored},
        include: (_) => true,
      );
      expect(days.single.earning, 800);
      expect(days.single.paidAmount, 500);
      expect(days.single.dueAmount, 400);
    },
  );
}
