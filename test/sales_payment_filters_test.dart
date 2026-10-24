import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/finance/presentation/sales_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/payment_method_tiles.dart';

void main() {
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('sales supports combined payments and All at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bills = [
        for (final entry in ['Cash', ' Card ', 'Online'].indexed)
          Bill(
            id: '${entry.$1}',
            createdAt: DateTime.now(),
            customerName: 'Customer ${entry.$1}',
            customerPhone: '',
            employeeName: 'Ali',
            paymentType: entry.$2,
            lines: const [BillLine(serviceName: 'Haircut', price: 1000)],
            subTotal: 1000,
            taxPercent: 17,
            taxAmount: 153,
            grandTotal: 1053,
            discountType: BillDiscountType.amount,
            discountValue: 100,
            discountAmount: 100,
          ),
      ];
      Bill? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: SalesScreen(
            suppliedBills: bills,
            title: 'My sales',
            employeeView: true,
            commissionByBill: const {'0': 400, '1': 400, '2': 400},
            onOpenBill: (bill) => opened = bill,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder tile(String label) => find.descendant(
        of: find.byType(PaymentMethodTiles),
        matching: find.widgetWithText(OutlinedButton, label),
      );
      await tester.tap(tile('Cash'));
      await tester.pumpAndSettle();
      expect(find.text('1 bill'), findsNWidgets(2));
      await tester.tap(tile('Card'));
      await tester.pumpAndSettle();
      expect(find.text('2 bills'), findsNWidgets(2));
      await tester.tap(tile('All'));
      await tester.pumpAndSettle();
      expect(find.text('3 bills'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('Customer 0'), 180);
      await tester.tap(find.text('Customer 0'));
      expect(opened?.id, '0');
      expect(tester.takeException(), isNull);
    });
  }
}
