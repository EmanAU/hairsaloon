class SalaryPayout {
  const SalaryPayout({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workDate,
    required this.amount,
    required this.settledAt,
    this.note,
    this.bonusAmount = 0,
  });

  final String id;
  final String employeeId;
  final String employeeName;

  /// Day the employee earned this amount; profit is charged on this day.
  final DateTime workDate;
  final double amount;
  final double bonusAmount;
  double get incomeAmount => amount - bonusAmount;
  final DateTime settledAt;
  final String? note;

  static String dayKey(String employeeId, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return 'payout:$employeeId:day:${d.toIso8601String()}';
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'period': 'day',
    'anchorDate': workDate.toIso8601String(),
    'amount': amount,
    'bonusAmount': bonusAmount,
    'createdAt': settledAt.toIso8601String(),
    'note': note,
  };

  factory SalaryPayout.fromMap(Map<String, dynamic> map) {
    final settledAt =
        DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
        DateTime.now();
    final workDate =
        DateTime.tryParse((map['anchorDate'] ?? '').toString()) ?? settledAt;
    final note = map['note']?.toString().trim();
    return SalaryPayout(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employeeId'] ?? '').toString(),
      employeeName: (map['employeeName'] ?? '').toString(),
      workDate: DateTime(workDate.year, workDate.month, workDate.day),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      bonusAmount: (map['bonusAmount'] as num?)?.toDouble() ?? 0,
      settledAt: settledAt,
      note: (note == null || note.isEmpty) ? null : note,
    );
  }
}
