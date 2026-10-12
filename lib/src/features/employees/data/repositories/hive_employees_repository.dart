import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveEmployeesRepository {
  HiveEmployeesRepository({Box<Map>? box})
    : _box = box ?? Hive.box<Map>(HiveBoxes.employees);

  final Box<Map> _box;

  List<EmployeeItem> getAll() {
    if (_box.isEmpty) {
      _seedDefaults();
    }
    final values = _box.values
        .map((item) => _employeeFromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return values;
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
    speciality: map['speciality']?.toString(),
    employeeType: map['employeeType']?.toString(),
    basicSalary: map['basicSalary']?.toString(),
    commission: map['commission']?.toString(),
    agreementDescription: map['agreementDescription']?.toString(),
  );
}

const List<EmployeeItem> _defaultEmployees = <EmployeeItem>[
  EmployeeItem(
    id: 'emp-1',
    firstName: 'Ali',
    lastName: 'Raza',
    phoneNumber: '+923001234567',
    cnicNumber: '35202-1234567-1',
    homeAddress: 'G-11 Markaz, Islamabad',
    isActive: true,
    speciality: 'Haircut Specialist',
    employeeType: 'Stylist',
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
    speciality: 'Color Specialist',
    employeeType: null,
    basicSalary: null,
    commission: null,
    agreementDescription: null,
  ),
  EmployeeItem(
    id: 'emp-3',
    firstName: 'M.',
    lastName: 'Aslam',
    phoneNumber: '+923221234567',
    cnicNumber: '61101-2233445-7',
    homeAddress: 'Blue Area, Islamabad',
    isActive: true,
    speciality: 'Haircut Specialist',
    employeeType: 'Senior Barber',
    basicSalary: '50000',
    commission: '15',
    agreementDescription: 'Fixed salary with tiered commission.',
  ),
];
