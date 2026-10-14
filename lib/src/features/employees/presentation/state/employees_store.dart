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

  Set<String> get _knownIds => _all.map((e) => e.id).toSet();

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

  List<EmployeeItem> assignTargets({String? excludeId}) {
    return _all
        .where((e) => e.id != excludeId)
        .toList(growable: false);
  }

  /// True if [employeeId] cannot be assigned to [targetId] (reverse/cycle).
  bool wouldCreateCycle(String employeeId, String targetId) {
    return wouldCreateAssignmentCycle(
      employeeId: employeeId,
      targetId: targetId,
      employees: _all,
    );
  }

  List<EmployeeItem> assignedPeople(EmployeeItem employee) {
    return employee.assignedToIds
        .map(byId)
        .whereType<EmployeeItem>()
        .toList(growable: false);
  }

  String assignedToLabel(EmployeeItem employee) {
    final people = assignedPeople(employee);
    if (people.isEmpty) return 'Unassigned';
    return people.map((e) => e.fullName).join(', ');
  }

  List<EmployeeItem> peopleAssignedTo(String employeeId) {
    return _all
        .where((e) => e.assignedToIds.contains(employeeId))
        .toList(growable: false);
  }

  Future<void> add(EmployeeItem item) async {
    final cleaned = item.copyWith(
      assignedToIds: sanitizeAssignedToIds(
        selfId: item.id,
        ids: item.assignedToIds,
        knownIds: _knownIds,
        employees: _all,
      ),
    );
    await _repository.add(cleaned);
    await _maybePersistCategory(cleaned.employeeType);
    _reload();
  }

  Future<void> update(EmployeeItem item) async {
    final withSelf = [..._all.where((e) => e.id != item.id), item];
    final cleaned = item.copyWith(
      assignedToIds: sanitizeAssignedToIds(
        selfId: item.id,
        ids: item.assignedToIds,
        knownIds: {..._knownIds, item.id},
        employees: withSelf,
      ),
    );
    await _repository.update(cleaned);
    await _maybePersistCategory(cleaned.employeeType);
    _reload();
  }

  Future<void> delete(String id) async {
    for (final employee in _all) {
      if (!employee.assignedToIds.contains(id)) continue;
      await _repository.update(
        employee.copyWith(
          assignedToIds: employee.assignedToIds
              .where((otherId) => otherId != id)
              .toList(growable: false),
        ),
      );
    }
    await _repository.delete(id);
    _reload();
  }

  Future<void> setAssignedTo({
    required String employeeId,
    required Iterable<String> assignedToIds,
  }) async {
    final employee = byId(employeeId);
    if (employee == null) return;
    // Empty list is a valid unassign — never treat it as "no change" wrongly.
    final next = assignedToIds.isEmpty
        ? const <String>[]
        : sanitizeAssignedToIds(
            selfId: employeeId,
            ids: assignedToIds,
            knownIds: _knownIds,
            employees: _all,
          );
    if (_sameIds(employee.assignedToIds, next)) return;
    await _repository.update(employee.copyWith(assignedToIds: next));
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

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final other = b.toSet();
    return a.every(other.contains);
  }
}
