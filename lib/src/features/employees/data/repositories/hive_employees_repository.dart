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

  List<EmployeeItem> getAll() {
    if (_box.isEmpty) {
      _seedDefaults();
    }
    return _box.values
        .map((item) => _employeeFromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  List<String> getCustomSpecialistCategories() {
    final raw = _metaBox.get(_specialistCategoriesKey);
    if (raw is! List) return const <String>[];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
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

  Future<void> _seedDefaults() async {
    for (final item in _defaultEmployees) {
      await _box.put(item.id, _employeeToMap(item));
    }
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
    'role': item.role.name,
    'managerId': item.managerId,
    'photoBase64': item.photoBase64,
    'speciality': item.speciality,
    'employeeType': item.employeeType,
    'basicSalary': item.basicSalary,
    'commission': item.commission,
    'agreementDescription': item.agreementDescription,
  };
}

EmployeeItem _employeeFromMap(Map<String, dynamic> map) {
  return EmployeeItem(
    id: (map['id'] ?? '').toString(),
    firstName: (map['firstName'] ?? '').toString(),
    lastName: (map['lastName'] ?? '').toString(),
    phoneNumber: (map['phoneNumber'] ?? '').toString(),
    cnicNumber: (map['cnicNumber'] ?? '').toString(),
    homeAddress: (map['homeAddress'] ?? '').toString(),
    isActive: (map['isActive'] as bool?) ?? false,
    role: EmployeeRole.fromStorage(map['role']?.toString()),
    managerId: map['managerId']?.toString(),
    photoBase64: map['photoBase64']?.toString(),
    speciality: map['speciality']?.toString(),
    employeeType: map['employeeType']?.toString(),
    basicSalary: map['basicSalary']?.toString(),
    commission: map['commission']?.toString(),
    agreementDescription: map['agreementDescription']?.toString(),
  );
}

const List<EmployeeItem> _defaultEmployees = <EmployeeItem>[
  EmployeeItem(
    id: 'mgr-1',
    firstName: 'Hassan',
    lastName: 'Ali',
    phoneNumber: '+923001112233',
    cnicNumber: '35202-1111222-3',
    homeAddress: 'F-7, Islamabad',
    isActive: true,
    role: EmployeeRole.manager,
    speciality: 'Floor Manager',
    employeeType: 'General',
  ),
  EmployeeItem(
    id: 'emp-1',
    firstName: 'Ali',
    lastName: 'Raza',
    phoneNumber: '+923001234567',
    cnicNumber: '35202-1234567-1',
    homeAddress: 'G-11 Markaz, Islamabad',
    isActive: true,
    role: EmployeeRole.employee,
    managerId: 'mgr-1',
    speciality: 'Haircut Specialist',
    employeeType: 'Men Specialist',
    basicSalary: '40000',
    commission: '10',
    agreementDescription: 'Monthly salary plus service commission.',
  ),
  EmployeeItem(
    id: 'emp-2',
    firstName: 'Sana',
    lastName: 'Khan',
    phoneNumber: '+923111234567',
    cnicNumber: '35202-7654321-9',
    homeAddress: 'F-10, Islamabad',
    isActive: false,
    role: EmployeeRole.employee,
    speciality: 'Color Specialist',
    employeeType: 'Women Specialist',
  ),
  EmployeeItem(
    id: 'emp-3',
    firstName: 'M.',
    lastName: 'Aslam',
    phoneNumber: '+923221234567',
    cnicNumber: '61101-2233445-7',
    homeAddress: 'Blue Area, Islamabad',
    isActive: true,
    role: EmployeeRole.employee,
    managerId: 'mgr-1',
    speciality: 'Haircut Specialist',
    employeeType: 'Men Specialist',
    basicSalary: '50000',
    commission: '15',
    agreementDescription: 'Fixed salary with tiered commission.',
  ),
];
