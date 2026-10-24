import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/customer_contact.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveBillingRepository {
  HiveBillingRepository({
    Box<Map>? billsBox,
    Box<String>? phonesBox,
    Box<Map>? contactsBox,
  }) : _billsBox = billsBox ?? Hive.box<Map>(HiveBoxes.bills),
       _phonesBox = phonesBox ?? Hive.box<String>(HiveBoxes.customerPhones),
       _contactsBox = contactsBox ?? Hive.box<Map>(HiveBoxes.customerContacts);

  final Box<Map> _billsBox;
  final Box<String> _phonesBox;
  final Box<Map> _contactsBox;

  List<Bill> getBills() {
    final values = _billsBox.values
        .map((item) => Bill.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  Bill? getById(String id) {
    final raw = _billsBox.get(id);
    if (raw == null) return null;
    return Bill.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveBill(Bill bill) async {
    await _billsBox.put(bill.id, bill.toJson());
    await addOrUpdateCustomerContact(
      name: bill.customerName,
      phone: bill.customerPhone,
    );
  }

  List<String> getCustomerPhones() {
    return _phonesBox.values.toList(growable: false);
  }

  Future<bool> addKnownCustomerPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    final exists = _phonesBox.containsKey(_keyFor(_phonesBox, phone));
    if (exists) return false;
    await _phonesBox.put(normalized, phone.trim());
    return true;
  }

  CustomerContact? getCustomerContactByPhone(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return null;
    final raw = _contactsBox.get(_keyFor(_contactsBox, phone));
    if (raw == null) return null;
    return CustomerContact.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<bool> addOrUpdateCustomerContact({
    required String name,
    required String phone,
  }) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;

    final trimmedPhone = phone.trim();
    final trimmedName = name.trim();

    final contactKey = _keyFor(_contactsBox, phone);
    final existingRaw = _contactsBox.get(contactKey);
    final existing = existingRaw == null
        ? null
        : CustomerContact.fromJson(Map<String, dynamic>.from(existingRaw));

    final merged = CustomerContact(
      name: trimmedName.isNotEmpty ? trimmedName : (existing?.name ?? ''),
      phone: trimmedPhone.isNotEmpty ? trimmedPhone : (existing?.phone ?? ''),
    );

    await _contactsBox.put(contactKey, merged.toJson());
    await _phonesBox.put(_keyFor(_phonesBox, phone), merged.phone.trim());
    return existing == null;
  }

  bool hasKnownCustomerPhone(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    return _phonesBox.containsKey(_keyFor(_phonesBox, phone));
  }

  bool hasKnownCustomerContact(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    return _contactsBox.containsKey(_keyFor(_contactsBox, phone));
  }

  List<String> searchCustomerPhones(String query) {
    final normalized = _normalizePhone(query);
    if (normalized.isEmpty) return const <String>[];
    return _phonesBox.values
        .where((phone) => _matchesPhone(phone, normalized))
        .toList(growable: false);
  }

  List<CustomerContact> searchCustomerContacts(String query) {
    final normalized = _normalizePhone(query);
    if (normalized.isEmpty) return const <CustomerContact>[];

    final values = _contactsBox.values
        .map((raw) => CustomerContact.fromJson(Map<String, dynamic>.from(raw)))
        .where((c) => _matchesPhone(c.phone, normalized))
        .toList(growable: false);

    values.sort((a, b) => b.phone.length.compareTo(a.phone.length));
    return values;
  }

  static bool _matchesPhone(String phone, String query) =>
      _normalizePhone(phone).contains(query) ||
      PkPhone.localNumber(phone).contains(query);

  // Resolve old local-format keys without deleting or rewriting customer history.
  static String _keyFor(Box box, String phone) {
    final normalized = _normalizePhone(phone);
    if (box.containsKey(normalized)) return normalized;
    for (final key in box.keys) {
      if (_normalizePhone(key.toString()) == normalized) return key.toString();
    }
    return normalized;
  }

  static String _normalizePhone(String value) {
    return PkPhone.normalize(value.replaceAll(RegExp(r'[^0-9+]'), ''));
  }
}
