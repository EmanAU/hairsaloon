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
  List<EmployeeItem> get employees => _all;

  EmployeeItem? get manager {
    for (final employee in _all) {
      if (employee.isManager) return employee;
    }
    return null;
  }

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

  EmployeeItem? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final employee in _all) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  Future<void> add(EmployeeItem item) async {
    var toSave = item;
    if (item.isManager) {
      await _clearOtherManagers(exceptId: item.id);
    }
    await _repository.add(toSave);
    await _maybePersistCategory(toSave.employeeType);
    _reload();
  }

  Future<void> update(EmployeeItem item) async {
    if (item.isManager) {
      await _clearOtherManagers(exceptId: item.id);
    }
    await _repository.update(item);
    await _maybePersistCategory(item.employeeType);
    _reload();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _reload();
  }

  /// Makes [employeeId] the only manager. Pass null / empty to clear.
  Future<void> setManager(String? employeeId) async {
    final targetId = (employeeId ?? '').trim();
    if (targetId.isEmpty) {
      await _clearOtherManagers();
      _reload();
      return;
    }
    final employee = byId(targetId);
    if (employee == null) return;
    await _clearOtherManagers(exceptId: targetId);
    if (!employee.isManager) {
      await _repository.update(employee.copyWith(isManager: true));
    }
    _reload();
  }

  Future<void> removeManager(String employeeId) async {
    final employee = byId(employeeId);
    if (employee == null || !employee.isManager) return;
    await _repository.update(employee.copyWith(isManager: false));
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

  Future<void> _clearOtherManagers({String? exceptId}) async {
    for (final employee in _all) {
      if (!employee.isManager) continue;
      if (exceptId != null && employee.id == exceptId) continue;
      await _repository.update(employee.copyWith(isManager: false));
    }
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
    // Enforce single manager if legacy data had more than one.
    final managers = _all.where((e) => e.isManager).toList(growable: false);
    if (managers.length > 1) {
      for (var i = 1; i < managers.length; i++) {
        _repository.update(managers[i].copyWith(isManager: false));
      }
      _all = _repository.getAll();
    }
    notifyListeners();
  }
}
