import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/settings/data/repositories/hive_settings_repository.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore({required HiveSettingsRepository repository})
    : _repository = repository,
      _taxRate = repository.getTaxRate(),
      _currencyCode = repository.getCurrencyCode();

  final HiveSettingsRepository _repository;

  static const List<String> defaultExpenseTypes = <String>[
    'Utilities',
    'Supplies',
    'Maintenance',
    'Tea/Coffee',
    'Rent',
    'Salary Advance',
    'Marketing',
    'Transport',
    'Cleaning',
    'Miscellaneous',
  ];

  List<String> get paymentMethods => [
    'Cash',
    'Card',
    'Online',
    ..._repository.getPaymentAccounts(),
  ];
  List<String> get paymentAccounts => _repository.getPaymentAccounts();

  List<String> get customExpenseTypes =>
      _repository.getCustomExpenseTypes();

  /// Defaults + user-added types (unique, case-insensitive).
  List<String> get expenseTypes {
    final seen = <String>{};
    final result = <String>[];
    for (final type in [...defaultExpenseTypes, ...customExpenseTypes]) {
      final key = type.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(type.trim());
    }
    return result;
  }

  Future<void> addExpenseType(String type) async {
    final trimmed = type.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Enter an expense type.');
    }
    if (expenseTypes.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('This expense type already exists.');
    }
    final custom = customExpenseTypes..add(trimmed);
    await _repository.saveCustomExpenseTypes(custom);
    notifyListeners();
  }

  Future<void> removeExpenseType(String type) async {
    final trimmed = type.trim();
    final isDefault = defaultExpenseTypes.any(
      (t) => t.toLowerCase() == trimmed.toLowerCase(),
    );
    if (isDefault) {
      throw ArgumentError('Default expense types cannot be removed.');
    }
    await _repository.saveCustomExpenseTypes(
      customExpenseTypes
          .where((t) => t.toLowerCase() != trimmed.toLowerCase())
          .toList(),
    );
    notifyListeners();
  }

  Future<void> savePaymentAccount({
    String? previous,
    required String method,
    required String holder,
  }) async {
    if (method.trim().isEmpty || holder.trim().isEmpty) {
      throw ArgumentError('Enter the payment method and account holder.');
    }
    final label = '${method.trim()} — ${holder.trim()}';
    final accounts = paymentAccounts;
    if (accounts.any(
      (v) => v != previous && v.toLowerCase() == label.toLowerCase(),
    )) {
      throw ArgumentError('This payment account already exists.');
    }
    final index = previous == null ? -1 : accounts.indexOf(previous);
    if (index < 0) {
      accounts.add(label);
    } else {
      accounts[index] = label;
    }
    await _repository.savePaymentAccounts(accounts);
    notifyListeners();
  }

  Future<void> removePaymentAccount(String label) async {
    await _repository.savePaymentAccounts(paymentAccounts..remove(label));
    notifyListeners();
  }

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
