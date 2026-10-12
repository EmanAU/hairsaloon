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
    final exists = _phonesBox.containsKey(normalized);
    if (exists) return false;
    await _phonesBox.put(normalized, phone.trim());
    return true;
  }

  CustomerContact? getCustomerContactByPhone(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return null;
    final raw = _contactsBox.get(normalized);
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

    final existingRaw = _contactsBox.get(normalized);
    final existing = existingRaw == null
        ? null
        : CustomerContact.fromJson(Map<String, dynamic>.from(existingRaw));

    final merged = CustomerContact(
      name: trimmedName.isNotEmpty ? trimmedName : (existing?.name ?? ''),
      phone: trimmedPhone.isNotEmpty ? trimmedPhone : (existing?.phone ?? ''),
    );

    await _contactsBox.put(normalized, merged.toJson());
    await _phonesBox.put(normalized, merged.phone.trim());
    return existing == null;
  }

  bool hasKnownCustomerPhone(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    return _phonesBox.containsKey(normalized);
  }

  bool hasKnownCustomerContact(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    return _contactsBox.containsKey(normalized);
  }

  List<String> searchCustomerPhones(String query) {
    final normalized = _normalizePhone(query);
    if (normalized.isEmpty) return const <String>[];
    return _phonesBox.values
        .where((phone) => _normalizePhone(phone).contains(normalized))
        .toList(growable: false);
  }

  List<CustomerContact> searchCustomerContacts(String query) {
    final normalized = _normalizePhone(query);
    if (normalized.isEmpty) return const <CustomerContact>[];

    final values = _contactsBox.values
        .map((raw) => CustomerContact.fromJson(Map<String, dynamic>.from(raw)))
        .where((c) => _normalizePhone(c.phone).contains(normalized))
        .toList(growable: false);

    values.sort((a, b) => b.phone.length.compareTo(a.phone.length));
    return values;
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
