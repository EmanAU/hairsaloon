import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:hairsaloon/src/core/utils/pk_cnic.dart';

void main() {
  test(
    'all phone input formats display local digits and retain canonical identity',
    () {
      final formatter = PkPhoneInputFormatter();
      for (final input in [
        '03465501748',
        '+923465501748',
        '00923465501748',
        '923465501748',
      ]) {
        final result = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: input),
        );
        expect(result.text, '03465501748');
        expect(PkPhone.normalize(result.text), '+923465501748');
      }
      expect(
        formatter
            .formatEditUpdate(TextEditingValue.empty, TextEditingValue.empty)
            .text,
        isEmpty,
      );
    },
  );
  test(
    'CNIC inputs use one display format without changing database digits',
    () {
      for (final input in ['1234512345671', '12345-1234567-1']) {
        expect(PkCnic.isValid(input), isTrue);
        expect(PkCnic.display(input), '12345-1234567-1');
        expect(PkCnic.digits(input), '1234512345671');
        expect(
          PkCnicInputFormatter()
              .formatEditUpdate(
                TextEditingValue.empty,
                TextEditingValue(text: input),
              )
              .text,
          '12345-1234567-1',
        );
      }
      expect(PkCnic.isValid('12345-1234567'), isFalse);
    },
  );
  test('profile phone requires an 11-digit local mobile number', () {
    expect(PkPhone.localValidationError('03127712502'), isNull);
    for (final invalid in [
      '',
      '0312771250',
      '031277125022',
      '02127712502',
      '+923127712502',
    ]) {
      expect(PkPhone.localValidationError(invalid), isNotNull);
    }
    expect(PkPhone.localNumber('+923127712502'), '03127712502');
    expect(PkPhone.normalize('03127712502'), '+923127712502');
  });
  test('normalizes and validates Pakistani mobiles', () {
    expect(PkPhone.normalize('03462254477'), '+923462254477');
    expect(PkPhone.normalize('+92 346 2254477'), '+923462254477');
    expect(PkPhone.normalize('00923462254477'), '+923462254477');
    expect(PkPhone.isValid('+923462254477'), isTrue);
    expect(PkPhone.isValid('+92346225447'), isFalse);
    expect(PkPhone.isValid('+9234622544771'), isFalse);
    expect(PkPhone.validationError('+923462254477'), isNull);
    expect(PkPhone.validationError('+92'), isNotNull);
  });
}
