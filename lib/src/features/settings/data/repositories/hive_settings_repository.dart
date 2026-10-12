import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveSettingsRepository {
  HiveSettingsRepository({Box<dynamic>? box})
    : _box = box ?? Hive.box<dynamic>(HiveBoxes.settings);

  static const String taxRateKey = 'tax_rate';
  static const String currencyCodeKey = 'currency_code';
  final Box<dynamic> _box;

  double getTaxRate() {
    final value = _box.get(taxRateKey);
    if (value is num) return value.toDouble();
    return 17.0;
  }

  Future<void> setTaxRate(double value) async {
    await _box.put(taxRateKey, value);
  }

  String getCurrencyCode() {
    final value = _box.get(currencyCodeKey);
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return 'PKR';
  }

  Future<void> setCurrencyCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;
    await _box.put(currencyCodeKey, normalized);
  }
}
