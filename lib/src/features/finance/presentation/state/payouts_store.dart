import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/finance/data/repositories/hive_payouts_repository.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';

class PayoutsStore extends ChangeNotifier {
  PayoutsStore({required HivePayoutsRepository repository})
    : _repository = repository {
    _reload();
  }

  final HivePayoutsRepository _repository;

  List<SalaryPayout> _payouts = const <SalaryPayout>[];
  Map<String, SalaryPayout> _byId = const <String, SalaryPayout>{};

  List<SalaryPayout> get payouts => _payouts;
  Map<String, SalaryPayout> get payoutsById => _byId;

  void _reload() {
    _payouts = _repository.getAll();
    _byId = {for (final p in _payouts) p.id: p};
  }

  bool isDaySettled(String employeeId, DateTime day) =>
      _byId.containsKey(SalaryPayout.dayKey(employeeId, day));

  double totalForPeriod(DateTime anchor, FinancePeriod period) {
    return _payouts
        .where((p) => FinanceCalculator.periodContains(p.workDate, anchor, period))
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  Future<void> settleDay({
    required EmployeeItem employee,
    required EmployeeDayIncome day,
    String? note,
  }) => settleDays(employee: employee, days: [day], note: note);

  Future<void> settleDays({
    required EmployeeItem employee,
    required List<EmployeeDayIncome> days,
    String? note,
  }) async {
    final now = DateTime.now();
    final trimmedNote = note?.trim();
    final payouts = days
        .where((d) => !d.isSettled && d.payableAmount > 0)
        .map(
          (d) => SalaryPayout(
            id: SalaryPayout.dayKey(employee.id, d.date),
            employeeId: employee.id,
            employeeName: employee.fullName,
            workDate: d.date,
            amount: d.payableAmount,
            settledAt: now,
            note: (trimmedNote == null || trimmedNote.isEmpty)
                ? null
                : trimmedNote,
          ),
        )
        .toList(growable: false);
    if (payouts.isEmpty) return;
    await _repository.saveAll(payouts);
    _reload();
    notifyListeners();
  }
}
