import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/online_app.dart';
import 'package:hairsaloon/src/online/presentation/employee_home.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'fake_online_repository.dart';

void main() {
  final profile = PersonalProfile(
    code: 'permanent-code',
    phone: '+923001234567',
    cnic: '1234512345671',
    dateOfBirth: DateTime(1995, 1, 1),
    workStartedOn: DateTime(2015, 1, 1),
    photoPath: 'user/photo.jpg',
  );

  testWidgets('joined staff land on employee home with daily jobs', (
    tester,
  ) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final repository = FakeOnlineRepository()..userId = 'barber';
    repository.workspace = OnlineWorkspace(
      account: const OnlineAccount(id: 'barber', name: 'Ali Barber'),
      profile: profile,
    );
    final dashboard = EmployeeDashboardData(
      contracts: [
        WorkContract(
          id: 'c1',
          employeeId: 'e1',
          businessId: 'salon',
          kind: 'daily',
          startsAt: today.subtract(const Duration(days: 1)),
          endsAt: null,
          status: 'accepted',
          salary: 0,
          commission: 40,
          terms: '',
          businessName: 'Cut & Co',
        ),
      ],
      joinRequests: const [],
      days: [
        EmployeeDayWork(
          date: today,
          jobs: [
            EmployeeWorkJob(
              id: 'b1',
              createdAt: today.add(const Duration(hours: 14)),
              customerName: 'Hassan',
              total: 1000,
              services: const ['Haircut'],
              businessName: 'Cut & Co',
              commissionPercent: 40,
            ),
          ],
        ),
      ],
    );
    expect(dashboard.liveContracts, hasLength(1));
    expect(dashboard.days, hasLength(1));
    repository.employeeDashboardData = dashboard;
    addTearDown(repository.events.close);

    final session = OnlineSession(repository);
    addTearDown(session.dispose);
    await session.reload();

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeHome(session: session, onSignOut: repository.signOut),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeHome), findsOneWidget);
    expect(find.text('Ali Barber'), findsOneWidget);
    expect(find.text('Cut & Co'), findsOneWidget);
    expect(find.text('Hassan'), findsOneWidget);
    expect(find.textContaining('Haircut'), findsOneWidget);

    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeHome), findsOneWidget);
    expect(find.text('Start a business'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
