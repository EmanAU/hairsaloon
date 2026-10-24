import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/presentation/employees_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'online/fake_online_repository.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/contracts_screen.dart';
import 'online/customer_experience_test.dart' show loadFonts, capture;

class _MemoryBox<T> extends Fake implements Box<T> {
  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
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

class _Workspace extends Fake implements BusinessWorkspace {
  EmployeesStore? store;
  @override
  final FakeOnlineRepository repository = FakeOnlineRepository();
  @override
  final business = const SalonBusiness(
    id: 'salon',
    name: 'Salon',
    phone: '03465501748',
    type: 'Salon',
    city: 'Lahore',
    area: 'Area',
    address: 'Road',
    isActive: true,
  );
  @override
  Future<bool> syncEmployeeRecords() async {
    for (final employee in store?.employees ?? []) {
      await repository.saveEmployeeRecord(business.id, employee.onboardingData);
    }
    return true;
  }

  @override
  Future<void> synchronize() async {}

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('employee entry and form fit $width with keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await loadFonts(tester);
      final store = EmployeesStore(
        repository: HiveEmployeesRepository(
          box: _MemoryBox<Map>(),
          metaBox: _MemoryBox<dynamic>(),
        ),
      );
      addTearDown(store.dispose);
      final workspace = _Workspace();
      addTearDown(workspace.repository.events.close);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<EmployeesStore>.value(value: store),
              ChangeNotifierProvider<BusinessWorkspace>.value(value: workspace),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              debugShowCheckedModeBanner: false,
              home: const EmployeesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, 'Create employee'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          OutlinedButton,
          'Invite an existing profile or scan QR',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Create employee'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'employee-create-${width.toInt()}');
      expect(find.text('Add employee photo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save Employee'),
        250,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Employee'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'creating an unregistered employee immediately opens and saves the contract',
    (tester) async {
      final box = _MemoryBox<Map>();
      final store = EmployeesStore(
        repository: HiveEmployeesRepository(
          box: box,
          metaBox: _MemoryBox<dynamic>(),
        ),
      );
      final workspace = _Workspace()..store = store;
      addTearDown(store.dispose);
      addTearDown(workspace.repository.events.close);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EmployeesStore>.value(value: store),
            ChangeNotifierProvider<BusinessWorkspace>.value(value: workspace),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const EmployeesScreen(),
          ),
        ),
      );
      await tester.tap(find.text('Create employee'));
      await tester.pumpAndSettle();
      Future<void> fill(String label, String value) async {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pump();
      }

      await fill('First Name', 'Hassan');
      await fill('Google Email', 'hassan@example.test');
      for (final label in ['Date of birth', 'Work started on']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await fill('Phone Number', '03465501748');
      await fill('CNIC Number', '12345-1234567-1');
      await fill('Home Address', 'Lahore');
      final category = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('General').last);
      await tester.pumpAndSettle();
      await fill('Speciality', 'Haircut');
      await tester.ensureVisible(find.text('Save Employee'));
      await tester.tap(find.text('Save Employee'));
      await tester.pumpAndSettle();
      expect(find.byType(ProposeContractPage), findsOneWidget);
      expect(store.employees, hasLength(1));
      await fill('Basic salary', '5000');
      await fill('Commission (%)', '40');
      await tester.tap(find.text('Save contract'));
      await tester.pumpAndSettle();
      expect(find.byType(ProposeContractPage), findsNothing);
      expect(store.employees.single.commission, '40');
      expect(store.employees.single.onlineSynced, isFalse);
      expect(store.employees.single.contract?['kind'], 'permanent');
      expect(
        workspace
            .repository
            .employeeRecordRows
            .values.single['contract']['commission'],
        40,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
