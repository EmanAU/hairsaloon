import 'package:flutter/services.dart';

/// Pakistani mobile: `+92` + exactly 10 digits (e.g. `+923462254477`).
class PkPhone {
  const PkPhone._();

  static const String prefix = '+92';
  static const int localDigits = 10;
  static final RegExp validPattern = RegExp(r'^\+92\d{10}$');

  /// Strips spaces/dashes and normalizes common local formats to `+92…`.
  static String normalize(String? raw) {
    var value = (raw ?? '').replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('0092')) value = '+${value.substring(2)}';
    if (RegExp(r'^03\d{9}$').hasMatch(value)) {
      value = '+92${value.substring(1)}';
    }
    if (RegExp(r'^92\d{10}$').hasMatch(value)) value = '+$value';
    return value;
  }

  static bool isValid(String? raw) => validPattern.hasMatch(normalize(raw));

  /// Local display for a previously stored Pakistani mobile number.
  static String localNumber(String? raw) {
    final value = normalize(raw);
    return RegExp(r'^\+923\d{9}$').hasMatch(value)
        ? '0${value.substring(3)}'
        : (raw ?? '').trim();
  }

  static String? localValidationError(String? raw) =>
      RegExp(r'^03\d{9}$').hasMatch((raw ?? '').trim())
      ? null
      : 'Enter an 11-digit number starting with 03';

  /// Null when valid; otherwise a short user-facing message.
  static String? validationError(String? raw, {bool required = true}) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty || trimmed == prefix || trimmed == '+92 ') {
      return required ? 'Required' : null;
    }
    final normalized = normalize(trimmed);
    if (!validPattern.hasMatch(normalized)) {
      return 'Use +92 and 10 digits (e.g. +923462254477)';
    }
    return null;
  }
}

/// Forces `+92` prefix and caps local part at 10 digits.
class PkPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final onlyDigits = text.replaceAll(RegExp(r'[^0-9]'), '');

    String afterPrefixDigits;
    if (text.startsWith('+92')) {
      afterPrefixDigits = text.substring(3).replaceAll(RegExp(r'[^0-9]'), '');
    } else if (onlyDigits.startsWith('92')) {
      afterPrefixDigits = onlyDigits.substring(2);
    } else if (onlyDigits.startsWith('0') && onlyDigits.length > 1) {
      afterPrefixDigits = onlyDigits.substring(1);
    } else {
      afterPrefixDigits = onlyDigits;
    }

    if (afterPrefixDigits.length > PkPhone.localDigits) {
      afterPrefixDigits = afterPrefixDigits.substring(0, PkPhone.localDigits);
    }

    final formatted = '${PkPhone.prefix}$afterPrefixDigits';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
