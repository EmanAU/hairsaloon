import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';

void main() {
  test('no discount applies tax on subtotal', () {
    final t = BillTotals.compute(subTotal: 1000, taxPercent: 10);
    expect(t.discountAmount, 0);
    expect(t.taxAmount, 100);
    expect(t.grandTotal, 1100);
  });

  test('percent discount is applied before tax', () {
    final t = BillTotals.compute(
      subTotal: 1000,
      taxPercent: 10,
      discountType: BillDiscountType.percent,
      discountValue: 20,
    );
    expect(t.discountAmount, 200);
    expect(t.taxAmount, 80);
    expect(t.grandTotal, 880);
  });

  test('amount discount is capped at subtotal', () {
    final t = BillTotals.compute(
      subTotal: 500,
      taxPercent: 16,
      discountType: BillDiscountType.amount,
      discountValue: 900,
    );
    expect(t.discountAmount, 500);
    expect(t.taxAmount, 0);
    expect(t.grandTotal, 0);
  });

  test('discount fields round-trip and default for old bills', () {
    final bill = Bill(
      id: '1760000123456',
      createdAt: DateTime(2026, 10, 13),
      customerName: 'Ali',
      customerPhone: '0300',
      employeeName: 'Sam',
      paymentType: 'Cash',
      lines: const [BillLine(serviceName: 'Cut', price: 1000)],
      subTotal: 1000,
      taxPercent: 0,
      taxAmount: 0,
      grandTotal: 900,
      discountType: BillDiscountType.amount,
      discountValue: 100,
      discountAmount: 100,
    );
    final copy = Bill.fromJson(bill.toJson());
    expect(copy.discountType, BillDiscountType.amount);
    expect(copy.discountAmount, 100);
    expect(copy.shortNumber, '123456');

    final legacy = Bill.fromJson(
      Map<String, dynamic>.from(bill.toJson())
        ..remove('discountType')
        ..remove('discountValue')
        ..remove('discountAmount'),
    );
    expect(legacy.discountType, BillDiscountType.none);
    expect(legacy.hasDiscount, isFalse);
  });
}
