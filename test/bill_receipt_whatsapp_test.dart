import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/features/billing/presentation/bill_receipt_share.dart';

void main() {
  test('whatsAppPhoneDigits normalizes PK numbers for wa.me', () {
    expect(
      BillReceiptShare.whatsAppPhoneDigits('+92 300 1234567'),
      '923001234567',
    );
    expect(
      BillReceiptShare.whatsAppPhoneDigits('03001234567'),
      '923001234567',
    );
    expect(
      BillReceiptShare.whatsAppPhoneDigits('3001234567'),
      '923001234567',
    );
    expect(BillReceiptShare.whatsAppPhoneDigits(''), isNull);
    expect(BillReceiptShare.whatsAppPhoneDigits('abc'), isNull);
  });
}
