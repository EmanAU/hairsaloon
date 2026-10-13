import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/settle_salary_dialog.dart';

void main() {
  for (final width in [390.0, 800.0]) {
    testWidgets('payment validation and bonus confirmation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SettleSalaryResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showSettleSalaryDialog(
                    context: context,
                    employeeName: 'Ali',
                    days: [
                      EmployeeDayIncome(
                        date: DateTime(2026, 10, 14),
                        sales: 2000,
                        earning: 2000,
                        expenseCut: 0,
                        payableAmount: 2000,
                        payout: null,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a positive amount with up to 2 decimal places.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, '2200');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text('Confirm the extra amount as a bonus/tip.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();
      expect(result?.amount, 2200);
      expect(result?.bonusConfirmed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
