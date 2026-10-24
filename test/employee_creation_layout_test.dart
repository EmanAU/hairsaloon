import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/presentation/employees_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'online/customer_experience_test.dart' show loadFonts, capture;

class _MemoryBox<T> extends Fake implements Box<T> {
  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
  @override
  Iterable<T> get values => [];
  @override
  T? get(dynamic key, {T? defaultValue}) => defaultValue;
}

class _Workspace extends Fake implements BusinessWorkspace {
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
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<EmployeesStore>.value(value: store),
              ChangeNotifierProvider<BusinessWorkspace>.value(
                value: _Workspace(),
              ),
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
}
