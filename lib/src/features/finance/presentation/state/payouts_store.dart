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
    _byId = {};
    for (final p in _payouts.reversed) {
      final key = SalaryPayout.dayKey(p.employeeId, p.workDate);
      final previous = _byId[key];
      _byId[key] = SalaryPayout(
        id: key,
        employeeId: p.employeeId,
        employeeName: p.employeeName,
        workDate: p.workDate,
        amount: (previous?.amount ?? 0) + p.amount,
        bonusAmount: (previous?.bonusAmount ?? 0) + p.bonusAmount,
        settledAt: p.settledAt,
        note: p.note,
      );
    }
  }

  double totalForPeriod(DateTime anchor, FinancePeriod period) {
    return _payouts
        .where(
          (p) => FinanceCalculator.periodContains(p.workDate, anchor, period),
        )
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  bool _saving = false;

  Future<void> settleDays({
    required EmployeeItem employee,
    required List<EmployeeDayIncome> days,
    required double amount,
    bool bonusConfirmed = false,
    String? note,
  }) async {
    if (_saving) throw StateError('Payment is already being saved');
    if (!amount.isFinite || amount <= 0 || days.isEmpty) {
      throw ArgumentError('Enter a valid payment amount');
    }
    final selected = {
      for (final day in days) FinanceCalculator.dayOf(day.date): day,
    }.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    double dueFor(EmployeeDayIncome day) {
      final paid =
          _byId[SalaryPayout.dayKey(employee.id, day.date)]?.incomeAmount ?? 0;
      final due = day.payableAmount - paid;
      if (due <= 0.005) return 0;
      return double.parse(due.toStringAsFixed(2));
    }

    final totalDue = double.parse(
      selected
          .fold<double>(0, (sum, day) => sum + dueFor(day))
          .toStringAsFixed(2),
    );
    final payment = double.parse(amount.toStringAsFixed(2));
    final excess = double.parse((payment - totalDue).toStringAsFixed(2));
    final bonus = excess > 0 ? excess : 0.0;
    if (bonus > 0 && !bonusConfirmed) {
      throw StateError('Confirm the extra amount as bonus/tip');
    }
    final now = DateTime.now();
    var remaining = payment - bonus;
    final records = <SalaryPayout>[];
    for (var i = 0; i < selected.length; i++) {
      final day = selected[i];
      final due = dueFor(day);
      final allocation = double.parse(
        (remaining < due ? remaining : due).toStringAsFixed(2),
      );
      final extra = i == selected.length - 1 ? bonus : 0.0;
      if (allocation + extra > 0) {
        records.add(
          SalaryPayout(
            id: '${SalaryPayout.dayKey(employee.id, day.date)}:payment:${now.microsecondsSinceEpoch}:$i',
            employeeId: employee.id,
            employeeName: employee.fullName,
            workDate: day.date,
            amount: allocation + extra,
            bonusAmount: extra,
            settledAt: now,
            note: note?.trim().isEmpty == true ? null : note?.trim(),
          ),
        );
      }
      remaining = double.parse((remaining - allocation).toStringAsFixed(2));
    }
    _saving = true;
    try {
      await _repository.saveAll(records);
      _reload();
      notifyListeners();
    } finally {
      _saving = false;
    }
  }
}
