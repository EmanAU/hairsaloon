import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/online/data/workspace_adapters.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'online/fake_online_repository.dart';

class _FailingEmployeeRepository extends HiveEmployeesRepository {
  _FailingEmployeeRepository({required super.box, required super.metaBox});
  @override
  Future<void> update(EmployeeItem item) async =>
      throw const FileSystemException('Disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<Map> box;
  late Box<dynamic> settings;
  late EmployeesStore store;
  WidgetTester? activeTester;
  const employee = EmployeeItem(
    id: 'barber-membership',
    firstName: 'Ali',
    lastName: '',
    phoneNumber: '+923001234567',
    cnicNumber: '1234512345671',
    homeAddress: 'Lahore',
    isActive: true,
    onlineSynced: true,
    employeeType: 'General',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('employee_save_');
    Hive.init(directory.path);
    box = await Hive.openBox<Map>('employees');
    settings = await Hive.openBox<dynamic>('settings');
    final repository = HiveEmployeesRepository(box: box, metaBox: settings);
    await repository.add(employee);
    store = EmployeesStore(repository: repository);
  });
  tearDown(() async {
    store.dispose();
    Future<void> cleanUp() async {
      await Hive.close();
      await directory.delete(recursive: true);
    }

    if (activeTester != null) {
      await activeTester!.runAsync(cleanUp);
    } else {
      await cleanUp();
    }
    activeTester = null;
  });

  Future<void> openEditor(
    WidgetTester tester, {
    EmployeesStore? overrideStore,
  }) async {
    activeTester = tester;
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<EmployeesStore>.value(
        value: overrideStore ?? store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<EmployeeItem>(
                    builder: (_) => EmployeeDetailsScreen(
                      item: employee,
                      requireCompletion: true,
                    ),
                  ),
                ),
                child: const Text('Open employee'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open employee'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Save profile');
    await tester.tap(button);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'raw online CNIC and a single name save and leave completion screen',
    (tester) async {
      await openEditor(tester);
      expect(find.text('12345-1234567-1'), findsOneWidget);
      expect(find.text('Personal profile photo'), findsOneWidget);
      await save(tester);
      expect(find.text('Open employee'), findsOneWidget);
      expect(find.byType(EmployeeDetailsScreen), findsNothing);
      expect(store.byId(employee.id)?.onlineSynced, isTrue);
      expect(box.get(employee.id)?['onlineSynced'], isTrue);
      expect(store.byId(employee.id)?.cnicNumber, '12345-1234567-1');
    },
  );

  testWidgets(
    'storage failure shows a visible error and allows retry or back',
    (tester) async {
      final failedStore = EmployeesStore(
        repository: _FailingEmployeeRepository(box: box, metaBox: settings),
      );
      await openEditor(tester, overrideStore: failedStore);
      await save(tester);
      expect(find.byKey(const Key('employee-save-error')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open employee'), findsOneWidget);
      failedStore.dispose();
    },
  );

  test('owner personal phone is independent from the business phone', () async {
    final repository = FakeOnlineRepository()..userId = 'owner';
    final workspace = await BusinessWorkspace.open(
      repository,
      const SalonBusiness(
        id: 'salon',
        name: 'Salon',
        phone: '+923009999999',
        type: 'Salon',
        city: 'Lahore',
        area: 'Area',
        address: 'Address',
        isActive: true,
      ),
      const OnlineAccount(id: 'owner', name: 'Owner'),
      initializeHive: false,
      personalProfile: const PersonalProfile(
        code: 'owner-profile',
        phone: '+923008888888',
      ),
    );
    expect(
      (await WorkspaceAuth(workspace).getCurrentUser())?.phone,
      '+923008888888',
    );
    expect(
      (await WorkspaceProfile(workspace).getProfile())?.phoneNumber,
      '+923009999999',
    );
    expect(
      workspace.snapshot()['settings'].toString(),
      isNot(contains('personal_phone')),
    );
    workspace.dispose();
    await repository.events.close();
  });
}
