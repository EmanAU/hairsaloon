import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/manager_entry.dart';
import 'package:hairsaloon/src/online/presentation/employee_home.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'package:hairsaloon/src/online/presentation/workspace_screen.dart';
import 'fake_online_repository.dart';

void main() {
  late FakeOnlineRepository repository;
  late OnlineSession session;
  setUp(() async {
    repository = FakeOnlineRepository()..userId = 'employee';
    repository.workspace = const OnlineWorkspace(
      account: OnlineAccount(id: 'employee', name: 'Ali'),
    );
    session = OnlineSession(repository);
    await session.reload();
  });
  tearDown(() async {
    session.dispose();
    await repository.events.close();
  });

  testWidgets(
    'manager can choose employee dashboard and switch back to the shop chooser',
    (tester) async {
      repository.managerBusinessRows = [
        const ManagerBusiness(
          businessId: 'salon',
          businessName: 'Ali Salon',
          membershipId: 'membership',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(home: ManagerEntry(session: session)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Employee dashboard'), findsOneWidget);
      expect(find.text('Open shop as manager'), findsOneWidget);
      expect(find.text('Ali Salon'), findsOneWidget);
      await tester.tap(find.text('Employee dashboard'));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeHome), findsOneWidget);
      await tester.tap(find.byTooltip('Switch workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your workspace'), findsOneWidget);
    },
  );

  testWidgets('ordinary employee does not see manager access', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ManagerEntry(session: session)));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeHome), findsOneWidget);
    expect(find.text('Open shop as manager'), findsNothing);
    expect(find.byTooltip('Switch workspace'), findsNothing);
  });

  testWidgets('removed manager cannot open another shop workspace', (
    tester,
  ) async {
    const shop = SalonBusiness(
      id: 'foreign',
      name: 'Foreign Salon',
      phone: '03001234567',
      type: 'Salon',
      city: 'City',
      area: 'Area',
      address: 'Address',
      isActive: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          repository: repository,
          business: shop,
          asManager: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manager access is no longer available.'), findsOneWidget);
  });
}
