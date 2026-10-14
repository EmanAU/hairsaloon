import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

void main() {
  test('manager flag can be set and cleared via copyWith', () {
    const worker = EmployeeItem(
      id: 'a',
      firstName: 'A',
      lastName: '',
      phoneNumber: '+923001234567',
      cnicNumber: '35202-1234567-1',
      homeAddress: 'City',
      isActive: true,
    );
    final manager = worker.copyWith(isManager: true);
    expect(manager.isManager, isTrue);
    expect(manager.copyWith(isManager: false).isManager, isFalse);
  });
}
