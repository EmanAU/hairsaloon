import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

void main() {
  test('employee defaults to non-manager worker', () {
    const employee = EmployeeItem(
      id: '1',
      firstName: 'Ali',
      lastName: 'Raza',
      phoneNumber: '+923001234567',
      cnicNumber: '35202-1234567-1',
      homeAddress: 'Islamabad',
      isActive: true,
    );
    expect(employee.isManager, isFalse);
    expect(employee.copyWith(isManager: true).isManager, isTrue);
  });
}
