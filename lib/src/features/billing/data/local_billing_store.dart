import 'dart:convert';

import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:shared_preferences/shared_preferences.dart';

@Deprecated('Use BillingStore + HiveBillingRepository instead.')
class LocalBillingStore {
  LocalBillingStore._();

  static const String _storageKey = 'billing.saved_bills.v1';
  static const String _customerPhonesKey = 'billing.customer_phones.v1';
  static final List<Bill> _bills = <Bill>[];
  static final List<String> _customerPhones = <String>[];
  static SharedPreferences? _prefs;

  static List<Bill> get bills => List<Bill>.unmodifiable(_bills);
  static List<String> get customerPhones =>
      List<String>.unmodifiable(_customerPhones);

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _bills.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _bills
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map(
            (item) => Bill.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
    } catch (_) {
      _bills.clear();
    }

    final rawPhones =
        prefs.getStringList(_customerPhonesKey) ?? const <String>[];
    _customerPhones
      ..clear()
      ..addAll(rawPhones.where((phone) => phone.trim().isNotEmpty));

    // Migration: ensure phones from old bills are available for autocomplete.
    for (final bill in _bills) {
      addKnownCustomerPhone(bill.customerPhone, persist: false);
    }
    _persistCustomerPhones();
  }

  static void addBill(Bill bill) {
    _bills.insert(0, bill);
    addKnownCustomerPhone(bill.customerPhone, persist: false);
    _persist();
    _persistCustomerPhones();
  }

  static Bill? getById(String id) {
    for (final bill in _bills) {
      if (bill.id == id) return bill;
    }
    return null;
  }

  static void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    final encoded = jsonEncode(_bills.map((bill) => bill.toJson()).toList());
    prefs.setString(_storageKey, encoded);
  }

  static bool addKnownCustomerPhone(String phone, {bool persist = true}) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    final exists = _customerPhones.any(
      (item) => _normalizePhone(item) == normalized,
    );
    if (exists) return false;
    _customerPhones.insert(0, phone.trim());
    if (persist) _persistCustomerPhones();
    return true;
  }

  static bool hasKnownCustomerPhone(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    return _customerPhones.any((item) => _normalizePhone(item) == normalized);
  }

  static List<String> searchCustomerPhones(String query) {
    final normalized = _normalizePhone(query);
    if (normalized.isEmpty) return const <String>[];
    return _customerPhones
        .where((item) => _normalizePhone(item).contains(normalized))
        .toList(growable: false);
  }

  static void _persistCustomerPhones() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setStringList(_customerPhonesKey, List<String>.from(_customerPhones));
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
