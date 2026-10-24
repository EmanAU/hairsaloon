import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/online_app.dart';
import 'package:hairsaloon/src/online/presentation/employee_home.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'fake_online_repository.dart';
import 'customer_experience_test.dart' show loadFonts, capture;
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';

void main() {
  final profile = PersonalProfile(
    code: 'permanent-code',
    phone: '+923001234567',
    cnic: '1234512345671',
    dateOfBirth: DateTime(1995, 1, 1),
    workStartedOn: DateTime(2015, 1, 1),
    photoPath: 'user/photo.jpg',
  );

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('joined staff land on employee home with daily jobs $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadFonts(tester);
      final key = GlobalKey();
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
                total: 1053,
                bill: Bill(
                  id: 'b1',
                  createdAt: today,
                  customerName: 'Hassan',
                  customerPhone: '',
                  employeeName: 'Ali Barber',
                  paymentType: 'Cash',
                  lines: const [BillLine(serviceName: 'Haircut', price: 1000)],
                  subTotal: 1000,
                  taxPercent: 17,
                  taxAmount: 153,
                  grandTotal: 1053,
                  discountType: BillDiscountType.amount,
                  discountValue: 100,
                  discountAmount: 100,
                ),
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
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: EmployeeHome(session: session, onSignOut: repository.signOut),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, 'employee-home-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('My sales'));
      await tester.tap(find.text('My sales'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'employee-sales-${width.toInt()}');
      expect(find.text('Your commission'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeHome), findsOneWidget);
      expect(find.text('Ali Barber'), findsOneWidget);
      expect(find.text('Cut & Co'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Hassan'), 250);
      expect(find.text('Hassan'), findsOneWidget);
      await tester.tap(find.text('Hassan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Haircut'), findsOneWidget);
      await capture(tester, key, 'employee-sale-detail-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnlineApp(audience: AppAudience.business, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeHome), findsOneWidget);
      expect(find.text('Start a business'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
