import 'package:flutter/services.dart';

class PkCnic {
  const PkCnic._();
  static String digits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
  static bool isValid(String? value) =>
      RegExp(r'^\d{13}$').hasMatch(digits(value));
  static String display(String? value) {
    final number = digits(value);
    if (!isValid(number)) return (value ?? '').trim();
    return '${number.substring(0, 5)}-${number.substring(5, 12)}-${number.substring(12)}';
  }
}

class PkCnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 13 ? digits.substring(0, 13) : digits;
    final text = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 5 || i == 12) text.write('-');
      text.write(limited[i]);
    }
    final formatted = text.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
