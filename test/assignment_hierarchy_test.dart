import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

EmployeeItem _emp(String id, {List<String> assignedTo = const []}) {
  return EmployeeItem(
    id: id,
    firstName: id,
    lastName: '',
    phoneNumber: '',
    cnicNumber: '',
    homeAddress: '',
    isActive: true,
    assignedToIds: assignedTo,
  );
}

void main() {
  test('blocks reverse assignment when A is already assigned to B', () {
    final employees = [
      _emp('ali', assignedTo: ['bilal']),
      _emp('bilal'),
    ];

    expect(
      wouldCreateAssignmentCycle(
        employeeId: 'bilal',
        targetId: 'ali',
        employees: employees,
      ),
      isTrue,
    );
    expect(
      wouldCreateAssignmentCycle(
        employeeId: 'ali',
        targetId: 'bilal',
        employees: employees,
      ),
      isFalse,
    );
  });

  test('blocks longer hierarchy cycles', () {
    final employees = [
      _emp('a', assignedTo: ['b']),
      _emp('b', assignedTo: ['c']),
      _emp('c'),
    ];

    expect(
      wouldCreateAssignmentCycle(
        employeeId: 'c',
        targetId: 'a',
        employees: employees,
      ),
      isTrue,
    );
    expect(
      wouldCreateAssignmentCycle(
        employeeId: 'a',
        targetId: 'c',
        employees: employees,
      ),
      isFalse,
    );
  });

  test('sanitizeAssignedToIds drops reverse targets', () {
    final employees = [
      _emp('ali', assignedTo: ['bilal']),
      _emp('bilal'),
      _emp('cara'),
    ];

    final cleaned = sanitizeAssignedToIds(
      selfId: 'bilal',
      ids: ['ali', 'cara'],
      employees: employees,
    );
    expect(cleaned, ['cara']);
  });
}
