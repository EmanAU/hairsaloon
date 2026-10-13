class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.date,
    required this.employeeName,
    required this.amount,
    required this.status,
    required this.paymentType,
    required this.expenseType,
    required this.quantity,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final DateTime date;
  final String employeeName;
  final double amount;
  final String status;
  final String paymentType;
  final String? expenseType;
  final int? quantity;
  final String? description;
  final DateTime createdAt;

  bool get isPaid => normalizeStatus(status) == 'Paid';
  bool get isUnpaid => !isPaid;

  static String normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'paid') return 'Paid';
    if (value == 'unpaid') return 'Unpaid';
    return raw.trim().isEmpty ? 'Unpaid' : raw.trim();
  }

  ExpenseItem copyWith({
    String? id,
    DateTime? date,
    String? employeeName,
    double? amount,
    String? status,
    String? paymentType,
    String? expenseType,
    int? quantity,
    String? description,
    DateTime? createdAt,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      date: date ?? this.date,
      employeeName: employeeName ?? this.employeeName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentType: paymentType ?? this.paymentType,
      expenseType: expenseType ?? this.expenseType,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
