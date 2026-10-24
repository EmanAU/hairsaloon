import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/employee_payments_screen.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'customer_experience_test.dart' show loadFonts, capture;

EmployeeDashboardData history({double amount = 0, double bonus = 0}) =>
    EmployeeDashboardData.fromHistory(
      contracts: const [],
      joinRequests: const [],
      rows: [
        {
          'businessId': 'salon',
          'businessName': 'Ali Hair Studio',
          'employeeId': 'employee',
          'commission': '40',
          'bills': [
            {
              'id': 'before-signup',
              'createdAt': '2026-10-24T12:00:00',
              'customerName': 'Hassan',
              'employeeName': 'Ali',
              'employeeId': 'employee',
              'paymentType': 'Cash',
              'subTotal': 1000,
              'grandTotal': 1053,
              'taxPercent': 17,
              'taxAmount': 153,
              'discountType': 'amount',
              'discountValue': 100,
              'discountAmount': 100,
              'lines': [
                {'serviceName': 'Haircut', 'price': 1000, 'qty': 1},
              ],
            },
          ],
          'payouts': [
            if (amount > 0)
              {
                'id': 'payment-1',
                'employeeId': 'employee',
                'employeeName': 'Ali',
                'anchorDate': '2026-10-24T00:00:00',
                'createdAt': '2026-10-25T12:00:00',
                'amount': amount,
                'bonusAmount': bonus,
                'note': 'Cash received',
              },
          ],
        },
      ],
    );

void main() {
  test(
    'pre-signup work and partial settlements keep original service commission',
    () {
      final pending = history();
      expect(pending.days.single.sales, 1053);
      expect(pending.days.single.earning, 400);
      expect(pending.days.single.due, 400);
      expect(pending.days.single.settlementStatus, 'Pending');
      final partial = history(amount: 250, bonus: 50);
      expect(partial.days.single.due, 200);
      expect(partial.days.single.settlementStatus, 'Partially paid');
      final paid = history(amount: 450, bonus: 50);
      expect(paid.days.single.due, 0);
      expect(paid.days.single.settlementStatus, 'Paid');
      expect(paid.notifications.single.title, 'Payment recorded');
      expect(paid.notifications.single.payment?.payout.amount, 450);
      expect(paid.days.single.jobs.single.bill?.employeeId, 'employee');
    },
  );
  test(
    'notification ids are stable and a changed payment generates a new update',
    () {
      expect(
        history(amount: 100).notifications.single.id,
        history(amount: 100).notifications.single.id,
      );
      expect(
        history(amount: 100).notifications.single.id,
        isNot(history(amount: 400).notifications.single.id),
      );
    },
  );
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('settlement updates in app at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadFonts(tester);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: EmployeePaymentsScreen(
              days: history(amount: 200).days,
              onRefresh: () async => history(amount: 450, bonus: 50),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Partially paid'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Paid'), findsNWidgets(2));
      expect(find.text('Bonus included'), findsOneWidget);
      expect(find.text('Cash received'), findsOneWidget);
      await capture(tester, key, 'employee-paid-$width');
      final seen = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: EmployeeNotificationsScreen(
            notices: history(amount: 450).notifications,
            seen: seen,
            onRead: (notice) async => seen.add(notice.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment recorded'));
      await tester.pumpAndSettle();
      expect(seen, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
