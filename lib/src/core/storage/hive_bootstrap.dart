import 'dart:convert';

import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/customer_contact.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiveBootstrap {
  HiveBootstrap._();

  static const String _billingMigrationFlag = 'migration.billing.sp_to_hive.v1';
  static const String _legacyBillsKey = 'billing.saved_bills.v1';
  static const String _legacyPhonesKey = 'billing.customer_phones.v1';
  static const String _settingsTaxRateKey = 'tax_rate';

  static Future<void> init(SharedPreferences prefs) async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.bills),
      Hive.openBox<String>(HiveBoxes.customerPhones),
      Hive.openBox<Map>(HiveBoxes.customerContacts),
      Hive.openBox<Map>(HiveBoxes.employees),
      Hive.openBox<Map>(HiveBoxes.expenses),
      Hive.openBox<Map>(HiveBoxes.employeePayouts),
      Hive.openBox<Map>(HiveBoxes.services),
      Hive.openBox<Map>(HiveBoxes.categories),
      Hive.openBox<dynamic>(HiveBoxes.settings),
    ]);
    await _migrateLegacyBillingIfNeeded(prefs);
  }

  static Future<void> _migrateLegacyBillingIfNeeded(
    SharedPreferences prefs,
  ) async {
    final migrated = prefs.getBool(_billingMigrationFlag) ?? false;
    if (migrated) return;

    final billsBox = Hive.box<Map>(HiveBoxes.bills);
    final phonesBox = Hive.box<String>(HiveBoxes.customerPhones);
    final contactsBox = Hive.box<Map>(HiveBoxes.customerContacts);

    if (billsBox.isNotEmpty || phonesBox.isNotEmpty || contactsBox.isNotEmpty) {
      await prefs.setBool(_billingMigrationFlag, true);
      return;
    }

    final raw = prefs.getString(_legacyBillsKey);
    final legacyBills = <Bill>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            legacyBills.add(Bill.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {
        // Keep migration resilient; malformed legacy payload is ignored.
      }
    }

    for (final bill in legacyBills) {
      await billsBox.put(bill.id, bill.toJson());
    }

    final rawPhones = prefs.getStringList(_legacyPhonesKey) ?? const <String>[];
    for (final phone in rawPhones) {
      final normalized = phone.trim();
      if (normalized.isEmpty) continue;
      final key = _normalizePhone(normalized);
      await phonesBox.put(key, normalized);
      await contactsBox.put(
        key,
        CustomerContact(name: '', phone: normalized).toJson(),
      );
    }

    for (final bill in legacyBills) {
      final normalized = _normalizePhone(bill.customerPhone);
      if (normalized.isEmpty) continue;
      await phonesBox.put(normalized, bill.customerPhone.trim());
      if (bill.customerName.trim().isNotEmpty) {
        await contactsBox.put(
          normalized,
          CustomerContact(
            name: bill.customerName.trim(),
            phone: bill.customerPhone.trim(),
          ).toJson(),
        );
      } else if (!contactsBox.containsKey(normalized)) {
        await contactsBox.put(
          normalized,
          CustomerContact(name: '', phone: bill.customerPhone.trim()).toJson(),
        );
      }
    }

    final settingsBox = Hive.box<dynamic>(HiveBoxes.settings);
    if (!settingsBox.containsKey(_settingsTaxRateKey)) {
      await settingsBox.put(_settingsTaxRateKey, 17.0);
    }

    await prefs.setBool(_billingMigrationFlag, true);
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
