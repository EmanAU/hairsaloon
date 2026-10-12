import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/expenses/data/repositories/hive_expenses_repository.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';

class ExpensesStore extends ChangeNotifier {
  ExpensesStore({required HiveExpensesRepository repository})
    : _repository = repository {
    _items = _repository.getAll();
  }

  final HiveExpensesRepository _repository;

  List<ExpenseItem> _items = const <ExpenseItem>[];
  List<ExpenseItem> get items => _items;

  Future<void> add(ExpenseItem item) async {
    await _repository.add(item);
    _items = _repository.getAll();
    notifyListeners();
  }

  Future<void> update(ExpenseItem item) async {
    await _repository.update(item);
    _items = _repository.getAll();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _items = _repository.getAll();
    notifyListeners();
  }
}
