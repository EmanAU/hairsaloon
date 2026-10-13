import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/settle_salary_dialog.dart';

EmployeeDayIncome _day({
  required double sales,
  required double earning,
  required double payable,
}) {
  return EmployeeDayIncome(
    date: DateTime(2026, 10, 14),
    sales: sales,
    earning: earning,
    expenseCut: 0,
    payableAmount: payable,
    payout: null,
  );
}

void main() {
  for (final width in [390.0, 800.0]) {
    testWidgets('prefills base payment with remaining due at width $width', (
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
                    days: [_day(sales: 10000, earning: 1000, payable: 1000)],
                    salesTotal: 10000,
                    commissionPercent: 10,
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

      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Commission %'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);

      final baseField = tester.widget<TextField>(find.byType(TextField).first);
      expect(baseField.controller?.text, '1000');

      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();
      expect(result?.amount, 1000);
      expect(result?.bonusConfirmed, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('extra percent of sales requires confirm at width $width', (
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
                    days: [_day(sales: 10000, earning: 1000, payable: 1000)],
                    salesTotal: 10000,
                    commissionPercent: 10,
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

      await tester.tap(find.text('Percent'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.pumpAndSettle();

      expect(find.text('Extra tip/bonus'), findsWidgets);
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

      expect(result?.amount, 1200);
      expect(result?.bonusConfirmed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('extra fixed amount requires confirm at width $width', (
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
                    days: [_day(sales: 2000, earning: 2000, payable: 2000)],
                    salesTotal: 2000,
                    commissionPercent: 100,
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

      await tester.enterText(find.byType(TextField).at(1), '200');
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

    testWidgets(
      'paying exact remaining due does not ask for tip confirm at width $width',
      (tester) async {
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
                          sales: 2960,
                          earning: 296,
                          expenseCut: 0,
                          payableAmount: 296,
                          payout: null,
                        ),
                      ],
                      salesTotal: 2960,
                      commissionPercent: 10,
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

        // Simulate prior partial pay by editing base to remaining 1 of 296.
        await tester.enterText(find.byType(TextField).first, '1');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();

        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          find.text('Confirm the extra amount as a bonus/tip.'),
          findsNothing,
        );
        expect(result?.amount, 1);
        expect(result?.bonusConfirmed, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('partial base payment records without bonus at width $width', (
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
                    days: [_day(sales: 10000, earning: 1000, payable: 1000)],
                    salesTotal: 10000,
                    commissionPercent: 10,
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

      await tester.enterText(find.byType(TextField).first, '400');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();

      expect(result?.amount, 400);
      expect(result?.bonusConfirmed, isFalse);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
