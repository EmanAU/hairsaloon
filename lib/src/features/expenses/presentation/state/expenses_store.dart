import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/expenses/data/repositories/hive_expenses_repository.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';

class ExpensesStore extends ChangeNotifier {
  ExpensesStore({required HiveExpensesRepository repository})
    : _repository = repository {
    reload();
  }

  final HiveExpensesRepository _repository;

  List<ExpenseItem> _items = const <ExpenseItem>[];
  List<ExpenseItem> get items => List<ExpenseItem>.unmodifiable(_items);

  void reload() {
    _items = _repository.getAll();
    notifyListeners();
  }

  ExpenseItem? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return _repository.getById(id);
  }

  Future<void> add(ExpenseItem item) async {
    final normalized = item.copyWith(
      status: ExpenseItem.normalizeStatus(item.status),
    );
    await _repository.add(normalized);
    reload();
  }

  Future<void> update(ExpenseItem item) async {
    final normalized = item.copyWith(
      status: ExpenseItem.normalizeStatus(item.status),
    );
    await _repository.update(normalized);
    reload();
  }

  Future<void> markAsPaid(String id) async {
    final existing = getById(id);
    if (existing == null || existing.isPaid) return;
    await update(existing.copyWith(status: 'Paid'));
  }

  Future<void> markAsUnpaid(String id) async {
    final existing = getById(id);
    if (existing == null || existing.isUnpaid) return;
    await update(existing.copyWith(status: 'Unpaid'));
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    reload();
  }
}
