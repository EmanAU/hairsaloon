import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';

void main() {
  test('strips self, duplicates, blanks and unknown ids', () {
    expect(
      sanitizeAssignedToIds(
        selfId: 'a',
        ids: const ['a', 'b', 'b', '', 'c', 'missing'],
        knownIds: {'a', 'b', 'c'},
      ),
      ['b', 'c'],
    );
  });

  test('legacy empty assignment stays empty', () {
    expect(
      sanitizeAssignedToIds(selfId: 'a', ids: const []),
      isEmpty,
    );
  });
}
