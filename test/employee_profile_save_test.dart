import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_photo.dart';
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

class _MemoryBox<T> extends Fake implements Box<T> {
  final Map<dynamic, T> data = {};
  @override
  Iterable<T> get values => data.values;
  @override
  T? get(dynamic key, {T? defaultValue}) => data[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, T value) async {
    data[key] = value;
  }
}

class _PhotoRepository extends FakeOnlineRepository {
  String? requestedBarber;
  String? managedEmployee;
  String? managerPin;
  @override
  Future<void> setEmployeeManager({
    required String employeeId,
    required bool isManager,
    String? pin,
  }) async {
    managedEmployee = employeeId;
    managerPin = pin;
    await super.setEmployeeManager(
      employeeId: employeeId,
      isManager: isManager,
      pin: pin,
    );
  }

  @override
  Future<String?> profilePhoto({String? barberId}) async {
    requestedBarber = barberId;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Box<Map> box;
  late Box<dynamic> settings;
  late EmployeesStore store;
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
    box = _MemoryBox<Map>();
    settings = _MemoryBox<dynamic>();
    final repository = HiveEmployeesRepository(box: box, metaBox: settings);
    await repository.add(employee);
    store = EmployeesStore(repository: repository);
  });
  tearDown(() => store.dispose());

  Future<void> openEditor(
    WidgetTester tester, {
    EmployeesStore? overrideStore,
    FakeOnlineRepository? onlineRepository,
  }) async {
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
                      repository: onlineRepository,
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
    'linked manager assignment is saved remotely with a PIN before local role changes',
    (tester) async {
      final repository = _PhotoRepository();
      await openEditor(tester, onlineRepository: repository);
      await tester.tap(find.text('Shop manager'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '4-digit manager PIN',
        ),
        '1234',
      );
      await save(tester);
      expect(repository.managedEmployee, employee.id);
      expect(repository.managerPin, '1234');
      expect(store.byId(employee.id)?.isManager, isTrue);
      await repository.events.close();
    },
  );

  testWidgets(
    'linked staff photo requests the barber identity and never falls back to a local owner image',
    (tester) async {
      final repository = _PhotoRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeePhoto(
              employee: employee.copyWith(photoBase64: 'AQID'),
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.requestedBarber, employee.id);
      expect(find.byType(Image), findsNothing);
      await repository.events.close();
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
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(IconButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Open employee'), findsOneWidget);
      failedStore.dispose();
    },
  );

  test('owner personal phone is independent from the business phone', () async {
    final directory = await Directory.systemTemp.createTemp('owner_identity_');
    Hive.init(directory.path);
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
    await Hive.close();
    await directory.delete(recursive: true);
  });
}
