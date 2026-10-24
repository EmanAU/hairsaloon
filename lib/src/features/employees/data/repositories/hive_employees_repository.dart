import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveEmployeesRepository {
  HiveEmployeesRepository({Box<Map>? box, Box<dynamic>? metaBox})
    : _box = box ?? Hive.box<Map>(HiveBoxes.employees),
      _metaBox = metaBox ?? Hive.box<dynamic>(HiveBoxes.settings);

  static const _specialistCategoriesKey = 'employee_specialist_categories';

  final Box<Map> _box;
  final Box<dynamic> _metaBox;
  Stream<BoxEvent> watch() => _box.watch();

  List<EmployeeItem> getAll() {
    return _box.values
        .map((item) => _employeeFromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  List<String> getCustomSpecialistCategories() {
    final raw = _metaBox.get(_specialistCategoriesKey);
    if (raw is! List) return const <String>[];
    return raw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  Future<void> saveCustomSpecialistCategories(List<String> categories) async {
    await _metaBox.put(_specialistCategoriesKey, categories);
  }

  Future<void> add(EmployeeItem item) async {
    await _box.put(item.id, _employeeToMap(item));
  }

  Future<void> update(EmployeeItem item) async {
    await _box.put(item.id, _employeeToMap(item));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}

Map<String, dynamic> _employeeToMap(EmployeeItem item) {
  return <String, dynamic>{
    'id': item.id,
    'firstName': item.firstName,
    'lastName': item.lastName,
    'phoneNumber': item.phoneNumber,
    'cnicNumber': item.cnicNumber,
    'homeAddress': item.homeAddress,
    'isActive': item.isActive,
    'isManager': item.isManager,
    'onlineSynced': item.onlineSynced,
    'photoBase64': item.photoBase64,
    'speciality': item.speciality,
    'employeeType': item.employeeType,
    'basicSalary': item.basicSalary,
    'commission': item.commission,
    'agreementDescription': item.agreementDescription,
    'email': item.email,
    'dateOfBirth': item.dateOfBirth?.toIso8601String().substring(0, 10),
    'workStartedOn': item.workStartedOn?.toIso8601String().substring(0, 10),
  };
}

EmployeeItem _employeeFromMap(Map<String, dynamic> map) {
  final id = (map['id'] ?? '').toString();
  return EmployeeItem(
    id: id,
    firstName: (map['firstName'] ?? '').toString(),
    lastName: (map['lastName'] ?? '').toString(),
    phoneNumber: (map['phoneNumber'] ?? '').toString(),
    cnicNumber: (map['cnicNumber'] ?? '').toString(),
    homeAddress: (map['homeAddress'] ?? '').toString(),
    isActive: (map['isActive'] as bool?) ?? false,
    isManager: (map['isManager'] as bool?) ?? false,
    onlineSynced: (map['onlineSynced'] as bool?) ?? false,
    photoBase64: map['photoBase64']?.toString(),
    speciality: map['speciality']?.toString(),
    employeeType: map['employeeType']?.toString(),
    basicSalary: map['basicSalary']?.toString(),
    commission: map['commission']?.toString(),
    agreementDescription: map['agreementDescription']?.toString(),
    email: map['email']?.toString() ?? '',
    dateOfBirth: DateTime.tryParse(map['dateOfBirth']?.toString() ?? ''),
    workStartedOn: DateTime.tryParse(map['workStartedOn']?.toString() ?? ''),
  );
}
