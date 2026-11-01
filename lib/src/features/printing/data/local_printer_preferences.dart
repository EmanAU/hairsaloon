import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/receipt_printer.dart';

class LocalPrinterPreferences implements ReceiptPrinterPreferences {
  String _key(String scope) =>
      'receipt_printer.v1.${base64Url.encode(utf8.encode(scope))}';
  @override
  Future<ReceiptPrinterConfig?> load(String scope) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(scope));
    if (raw == null) return null;
    try {
      final config = ReceiptPrinterConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (config.validationError != null) throw const FormatException();
      return config;
    } catch (_) {
      throw const PrinterFailure(
        'Saved printer settings could not be read. Save the printer again in Business Settings.',
      );
    }
  }

  @override
  Future<void> save(String scope, ReceiptPrinterConfig config) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _key(scope),
      jsonEncode(config.toJson()),
    )) {
      throw const PrinterFailure(
        'Printer settings could not be saved on this device.',
      );
    }
  }

  @override
  Future<void> clear(String scope) async {
    if (!await (await SharedPreferences.getInstance()).remove(_key(scope))) {
      throw const PrinterFailure('Printer settings could not be removed.');
    }
  }
}
