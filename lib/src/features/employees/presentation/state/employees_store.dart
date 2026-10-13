import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

class EmployeesStore extends ChangeNotifier {
  EmployeesStore({required HiveEmployeesRepository repository})
    : _repository = repository {
    _reload();
  }

  static const List<String> defaultSpecialistCategories = <String>[
    'Men Specialist',
    'Women Specialist',
    'Kids Specialist',
    'General',
    'Other',
  ];

  final HiveEmployeesRepository _repository;

  List<EmployeeItem> _all = const <EmployeeItem>[];
  List<String> _customCategories = const <String>[];

  List<EmployeeItem> get all => _all;
  List<EmployeeItem> get employees =>
      _all.where((e) => !e.isManager).toList(growable: false);
  List<EmployeeItem> get managers =>
      _all.where((e) => e.isManager).toList(growable: false);

  List<String> get specialistCategories {
    final fromPeople = _all
        .map((e) => (e.employeeType ?? '').trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'other');
    return <String>{
      ...defaultSpecialistCategories.where((e) => e != 'Other'),
      ..._customCategories,
      ...fromPeople,
      'Other',
    }.toList(growable: false);
  }

  List<EmployeeItem> employeesForManager(String managerId) {
    return employees
        .where((e) => e.managerId == managerId)
        .toList(growable: false);
  }

  EmployeeItem? managerOf(String? managerId) {
    if (managerId == null || managerId.isEmpty) return null;
    for (final manager in managers) {
      if (manager.id == managerId) return manager;
    }
    return null;
  }

  Future<void> add(EmployeeItem item) async {
    await _repository.add(item);
    await _maybePersistCategory(item.employeeType);
    _reload();
  }

  Future<void> update(EmployeeItem item) async {
    await _repository.update(item);
    await _maybePersistCategory(item.employeeType);
    _reload();
  }

  Future<void> delete(String id) async {
    final target = _all.where((e) => e.id == id).firstOrNull;
    if (target != null && target.isManager) {
      for (final employee in employeesForManager(id)) {
        await _repository.update(employee.copyWith(clearManagerId: true));
      }
    }
    await _repository.delete(id);
    _reload();
  }

  Future<void> assignEmployeeToManager({
    required String employeeId,
    required String? managerId,
  }) async {
    final employee = _all.where((e) => e.id == employeeId).firstOrNull;
    if (employee == null || employee.isManager) return;
    if (managerId != null &&
        managers.every((manager) => manager.id != managerId)) {
      return;
    }
    await _repository.update(
      employee.copyWith(
        managerId: managerId,
        clearManagerId: managerId == null,
      ),
    );
    _reload();
  }

  Future<void> addSpecialistCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;
    if (specialistCategories.any(
      (c) => c.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return;
    }
    _customCategories = <String>[..._customCategories, trimmed];
    await _repository.saveCustomSpecialistCategories(_customCategories);
    notifyListeners();
  }

  Future<void> _maybePersistCategory(String? category) async {
    final trimmed = (category ?? '').trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'other') return;
    final exists = specialistCategories.any(
      (c) => c.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;
    await addSpecialistCategory(trimmed);
  }

  void _reload() {
    _all = _repository.getAll();
    _customCategories = _repository.getCustomSpecialistCategories();
    notifyListeners();
  }
}
