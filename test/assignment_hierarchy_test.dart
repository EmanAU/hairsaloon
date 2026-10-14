import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

void main() {
  test('only one manager role is represented on an employee', () {
    const ali = EmployeeItem(
      id: 'ali',
      firstName: 'Ali',
      lastName: '',
      phoneNumber: '+923001234567',
      cnicNumber: '35202-1234567-1',
      homeAddress: 'City',
      isActive: true,
      isManager: true,
    );
    const bilal = EmployeeItem(
      id: 'bilal',
      firstName: 'Bilal',
      lastName: '',
      phoneNumber: '+923001234568',
      cnicNumber: '35202-1234567-2',
      homeAddress: 'City',
      isActive: true,
    );
    expect(ali.isManager, isTrue);
    expect(bilal.isManager, isFalse);
  });
}
