import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveSettingsRepository {
  HiveSettingsRepository({Box<dynamic>? box, this.accountId})
    : _box = box ?? Hive.box<dynamic>(HiveBoxes.settings);

  static const String taxRateKey = 'tax_rate';
  static const String currencyCodeKey = 'currency_code';
  final Box<dynamic> _box;
  final String? Function()? accountId;

  String get _paymentKey =>
      'payment_accounts.v1.${accountId?.call() ?? "local"}';
  List<String> getPaymentAccounts() => List<String>.from(
    _box.get(_paymentKey, defaultValue: <String>[]) as List,
  );
  Future<void> savePaymentAccounts(List<String> values) =>
      _box.put(_paymentKey, values);

  String get _expenseTypesKey =>
      'expense_types.v1.${accountId?.call() ?? "local"}';
  List<String> getCustomExpenseTypes() => List<String>.from(
    _box.get(_expenseTypesKey, defaultValue: <String>[]) as List,
  );
  Future<void> saveCustomExpenseTypes(List<String> values) =>
      _box.put(_expenseTypesKey, values);

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
