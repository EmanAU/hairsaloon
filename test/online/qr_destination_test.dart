import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/qr_destination.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  test('public discovery and private joining destinations are distinct', () {
    for (final kind in ['salon', 'barber', 'join']) {
      final qr = QrDestination.parse('trimmatrix://$kind/$id');
      expect(qr?.kind, kind);
      expect(qr?.id, id);
      expect(qr?.value, 'trimmatrix://$kind/$id');
    }
  });
  test('rejects unrelated, malformed and ambiguous QR links', () {
    for (final value in [
      'https://salon/$id',
      'trimmatrix://admin/$id',
      'trimmatrix://salon/no-id',
      'trimmatrix://salon/$id/other',
      'trimmatrix://salon/$id?join=true',
      'trimmatrix://user@salon/$id',
      'trimmatrix://salon:123/$id',
      'trimmatrix://barber/$id#other',
    ]) {
      expect(QrDestination.parse(value), isNull, reason: value);
    }
  });
}
