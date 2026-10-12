import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveExpensesRepository {
  HiveExpensesRepository({Box<Map>? box})
    : _box = box ?? Hive.box<Map>(HiveBoxes.expenses);

  final Box<Map> _box;

  List<ExpenseItem> getAll() {
    if (_box.isEmpty) {
      _seedDefaults();
    }
    final values = _box.values
        .map((item) => _expenseFromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  Future<void> add(ExpenseItem item) async {
    await _box.put(item.id, _expenseToMap(item));
  }

  Future<void> update(ExpenseItem item) async {
    await _box.put(item.id, _expenseToMap(item));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> _seedDefaults() async {
    for (final item in _defaultExpenses) {
      await _box.put(item.id, _expenseToMap(item));
    }
  }
}

Map<String, dynamic> _expenseToMap(ExpenseItem item) {
  return <String, dynamic>{
    'id': item.id,
    'date': item.date.toIso8601String(),
    'employeeName': item.employeeName,
    'amount': item.amount,
    'status': item.status,
    'paymentType': item.paymentType,
    'expenseType': item.expenseType,
    'quantity': item.quantity,
    'description': item.description,
    'createdAt': item.createdAt.toIso8601String(),
  };
}

ExpenseItem _expenseFromMap(Map<String, dynamic> map) {
  return ExpenseItem(
    id: (map['id'] ?? '').toString(),
    date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
    employeeName: (map['employeeName'] ?? '').toString(),
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    status: (map['status'] ?? '').toString(),
    paymentType: (map['paymentType'] ?? '').toString(),
    expenseType: map['expenseType']?.toString(),
    quantity: (map['quantity'] as num?)?.toInt(),
    description: map['description']?.toString(),
    createdAt:
        DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
        DateTime.now(),
  );
}

final List<ExpenseItem> _defaultExpenses = <ExpenseItem>[
  ExpenseItem(
    id: 'exp-1',
    date: DateTime(2026, 3, 17),
    employeeName: 'Ali Raza',
    amount: 100,
    status: 'Paid',
    paymentType: 'Cash',
    expenseType: 'Tea/Coffee',
    quantity: 1,
    description: 'Buy some coffee',
    createdAt: DateTime(2026, 3, 17, 14, 15),
  ),
  ExpenseItem(
    id: 'exp-2',
    date: DateTime(2026, 3, 17),
    employeeName: 'Sana Khan',
    amount: 100,
    status: 'Unpaid',
    paymentType: 'Online',
    expenseType: 'Cleaning',
    quantity: 1,
    description: 'Buy some coffee',
    createdAt: DateTime(2026, 3, 17, 14, 15),
  ),
];
