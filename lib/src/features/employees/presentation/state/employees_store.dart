import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

class EmployeesStore extends ChangeNotifier {
  EmployeesStore({required HiveEmployeesRepository repository})
    : _repository = repository {
    _employees = _repository.getAll();
  }

  final HiveEmployeesRepository _repository;

  List<EmployeeItem> _employees = const <EmployeeItem>[];
  List<EmployeeItem> get employees => _employees;

  Future<void> add(EmployeeItem item) async {
    await _repository.add(item);
    _employees = _repository.getAll();
    notifyListeners();
  }

  Future<void> update(EmployeeItem item) async {
    await _repository.update(item);
    _employees = _repository.getAll();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _employees = _repository.getAll();
    notifyListeners();
  }
}
