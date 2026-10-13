import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';

class EmployeeDayIncome {
  const EmployeeDayIncome({
    required this.date,
    required this.sales,
    required this.earning,
    required this.expenseCut,
    required this.payableAmount,
    required this.payout,
  });

  final DateTime date;
  final double sales;
  final double earning;
  final double expenseCut;

  /// Full commission earning; shop expenses are accounted for separately.
  final double payableAmount;
  final SalaryPayout? payout;

  bool get isSettled => payout != null && dueAmount == 0;
  double get paidAmount => payout?.amount ?? 0;
  double get bonusAmount => payout?.bonusAmount ?? 0;
  double get dueAmount {
    final remaining = payableAmount - (payout?.incomeAmount ?? 0);
    return remaining > 0.005 ? remaining : 0;
  }
}

class FinanceDaySummary {
  const FinanceDaySummary({
    required this.date,
    required this.sales,
    required this.expenses,
    required this.salaries,
  });

  final DateTime date;
  final double sales;
  final double expenses;
  final double salaries;

  double get profit => sales - expenses - salaries;
}

class FinanceTotals {
  const FinanceTotals({
    required this.sales,
    required this.expenses,
    required this.salaries,
    required this.billCount,
  });

  final double sales;
  final double expenses;
  final double salaries;
  final int billCount;

  double get profit => sales - expenses - salaries;
}

class FinanceCalculator {
  const FinanceCalculator._();

  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime weekStart(DateTime anchor) =>
      dayOf(anchor).subtract(Duration(days: anchor.weekday - 1));

  static bool periodContains(
    DateTime date,
    DateTime anchor,
    FinancePeriod period,
  ) {
    final target = dayOf(date);
    switch (period) {
      case FinancePeriod.daily:
        return target == dayOf(anchor);
      case FinancePeriod.weekly:
        final start = weekStart(anchor);
        final end = start.add(const Duration(days: 6));
        return !target.isBefore(start) && !target.isAfter(end);
      case FinancePeriod.monthly:
        return target.year == anchor.year && target.month == anchor.month;
    }
  }

  static String norm(String value) => value.trim().toLowerCase();

  static double commissionPercent(String? value) {
    if (value == null || value.trim().isEmpty) return 100;
    final parsed =
        double.tryParse(value.replaceAll(',', '').replaceAll('%', '').trim()) ??
        0;
    return parsed <= 0 ? 100 : parsed;
  }

  static List<EmployeeDayIncome> employeeDays({
    required EmployeeItem employee,
    required List<Bill> bills,
    required List<ExpenseItem> expenses,
    required Map<String, SalaryPayout> payoutsById,
    required bool Function(DateTime date) include,
  }) {
    final name = norm(employee.fullName);
    final percent = commissionPercent(employee.commission);

    final salesByDay = <DateTime, double>{};
    for (final bill in bills) {
      if (norm(bill.employeeName) != name || !include(bill.createdAt)) {
        continue;
      }
      salesByDay.update(
        dayOf(bill.createdAt),
        (v) => v + bill.grandTotal,
        ifAbsent: () => bill.grandTotal,
      );
    }

    final days = <DateTime>{
      ...salesByDay.keys,
      ...payoutsById.values
          .where((p) => p.employeeId == employee.id && include(p.workDate))
          .map((p) => dayOf(p.workDate)),
    }.toList()..sort((a, b) => b.compareTo(a));

    return days
        .map((day) {
          final sales = salesByDay[day] ?? 0;
          final earning = sales * percent / 100;

          return EmployeeDayIncome(
            date: day,
            sales: sales,
            earning: earning,
            expenseCut: 0,
            payableAmount: double.parse(earning.toStringAsFixed(2)),
            payout: payoutsById[SalaryPayout.dayKey(employee.id, day)],
          );
        })
        .toList(growable: false);
  }

  static FinanceTotals totals({
    required List<Bill> bills,
    required List<ExpenseItem> expenses,
    required List<SalaryPayout> payouts,
    required DateTime anchor,
    required FinancePeriod period,
  }) {
    var sales = 0.0;
    var count = 0;
    for (final b in bills) {
      if (!periodContains(b.createdAt, anchor, period)) continue;
      sales += b.grandTotal;
      count++;
    }
    final exp = expenses
        .where((e) => periodContains(e.date, anchor, period))
        .fold<double>(0, (s, e) => s + e.amount);
    final sal = payouts
        .where((p) => periodContains(p.workDate, anchor, period))
        .fold<double>(0, (s, p) => s + p.amount);
    return FinanceTotals(
      sales: sales,
      expenses: exp,
      salaries: sal,
      billCount: count,
    );
  }

  static List<FinanceDaySummary> dailySummaries({
    required List<Bill> bills,
    required List<ExpenseItem> expenses,
    required List<SalaryPayout> payouts,
    required DateTime anchor,
    required FinancePeriod period,
  }) {
    final sales = <DateTime, double>{};
    final exp = <DateTime, double>{};
    final sal = <DateTime, double>{};
    void add(Map<DateTime, double> map, DateTime date, double value) {
      map.update(dayOf(date), (v) => v + value, ifAbsent: () => value);
    }

    for (final b in bills) {
      if (periodContains(b.createdAt, anchor, period)) {
        add(sales, b.createdAt, b.grandTotal);
      }
    }
    for (final e in expenses) {
      if (periodContains(e.date, anchor, period)) add(exp, e.date, e.amount);
    }
    for (final p in payouts) {
      if (periodContains(p.workDate, anchor, period)) {
        add(sal, p.workDate, p.amount);
      }
    }

    final days = <DateTime>{...sales.keys, ...exp.keys, ...sal.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    return days
        .map(
          (d) => FinanceDaySummary(
            date: d,
            sales: sales[d] ?? 0,
            expenses: exp[d] ?? 0,
            salaries: sal[d] ?? 0,
          ),
        )
        .toList(growable: false);
  }
}
