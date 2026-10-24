import 'package:flutter/services.dart';

/// Pakistani mobile: `+92` + exactly 10 digits (e.g. `+923462254477`).
class PkPhone {
  const PkPhone._();

  static const String prefix = '+92';
  static const String inputPrefix = '';
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
      return 'Enter an 11-digit number starting with 03 (e.g. 03465501748)';
    }
    return null;
  }
}

/// Shows local mobile numbers, including when an international number is pasted.
class PkPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var formatted = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (formatted.startsWith('0092')) {
      formatted = '0${formatted.substring(4)}';
    } else if (formatted.startsWith('92')) {
      formatted = '0${formatted.substring(2)}';
    } else if (formatted.startsWith('3')) {
      formatted = '0$formatted';
    }
    if (formatted.length > 11) formatted = formatted.substring(0, 11);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
