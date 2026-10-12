import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/settings/data/repositories/hive_settings_repository.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore({required HiveSettingsRepository repository})
    : _repository = repository,
      _taxRate = repository.getTaxRate(),
      _currencyCode = repository.getCurrencyCode();

  final HiveSettingsRepository _repository;

  double _taxRate;
  double get taxRate => _taxRate;

  String _currencyCode;
  String get currencyCode => _currencyCode;

  Future<void> setTaxRate(double value) async {
    if (value < 0 || value == _taxRate) return;
    await _repository.setTaxRate(value);
    _taxRate = value;
    notifyListeners();
  }

  Future<void> setCurrencyCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty || normalized == _currencyCode) return;
    await _repository.setCurrencyCode(normalized);
    _currencyCode = normalized;
    notifyListeners();
  }
}
