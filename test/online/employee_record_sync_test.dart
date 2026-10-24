import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'fake_online_repository.dart';

void main() {
  test(
    'employee outbox retains an offline record and never reactivates paused or departed staff',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'employee_outbox_',
      );
      Hive.init(directory.path);
      final repository = FakeOnlineRepository()
        ..userId = 'owner'
        ..failEmployeeRecords = true;
      const business = SalonBusiness(
        id: 'business',
        name: 'Salon',
        phone: '03001234567',
        type: 'Salon',
        city: 'Lahore',
        area: 'Area',
        address: 'Road',
        isActive: true,
      );
      final workspace = await BusinessWorkspace.open(
        repository,
        business,
        const OnlineAccount(id: 'owner', name: 'Owner'),
        initializeHive: false,
      );
      final store = EmployeesStore(
        repository: HiveEmployeesRepository(
          box: workspace.maps['employees'],
          metaBox: workspace.settings,
        ),
      );
      try {
        final employee = EmployeeItem(
          id: '00000000-0000-4000-8000-000000000001',
          firstName: 'Hassan',
          lastName: 'Ali',
          phoneNumber: '+923001234568',
          cnicNumber: '12345-1234567-1',
          homeAddress: 'Road',
          isActive: true,
          email: 'staff@example.test',
          dateOfBirth: DateTime(1997),
          workStartedOn: DateTime(2015),
        );
        await store.add(employee);
        expect(await workspace.syncEmployeeRecords(), isFalse);
        expect(store.byId(employee.id)?.dateOfBirth, DateTime(1997));
        expect(workspace.employeeRecordSynced(employee.id), isFalse);
        repository.failEmployeeRecords = false;
        expect(await workspace.syncEmployeeRecords(), isTrue);
        expect(repository.employeeRecordRows, hasLength(1));
        expect(workspace.employeeRecordSynced(employee.id), isTrue);
        repository.teamRows = [
          SalonStaff(
            id: employee.id,
            name: employee.fullName,
            isWorking: false,
            isActive: false,
          ),
        ];
        await workspace.syncOnlineTeam();
        await Future<void>.delayed(Duration.zero);
        expect(store.byId(employee.id)?.isActive, isFalse);
        expect(store.byId(employee.id)?.onlineSynced, isTrue);
        await workspace.syncOnlineTeam();
        expect(
          workspace.maps['employees']!.get(employee.id)?['isActive'],
          isFalse,
        );
        repository.teamRows = [
          SalonStaff(
            id: employee.id,
            name: employee.fullName,
            isWorking: false,
            isActive: false,
            joinStatus: 'left',
          ),
        ];
        await workspace.syncOnlineTeam();
        await Future<void>.delayed(Duration.zero);
        expect(store.byId(employee.id)?.isActive, isFalse);
        expect(store.byId(employee.id)?.isManager, isFalse);
        expect(store.byId(employee.id)?.email, 'staff@example.test');
      } finally {
        store.dispose();
        workspace.dispose();
        await Hive.close();
        await directory.delete(recursive: true);
        await repository.events.close();
      }
    },
  );
}
