import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/billing/data/repositories/hive_billing_repository.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/customer_contact.dart';

class BillingStore extends ChangeNotifier {
  BillingStore({required HiveBillingRepository repository})
    : _repository = repository {
    _hydrate();
  }

  final HiveBillingRepository _repository;

  List<Bill> _bills = const <Bill>[];
  List<String> _customerPhones = const <String>[];

  List<Bill> get bills => _bills;
  List<String> get customerPhones => _customerPhones;

  void _hydrate() {
    _bills = _repository.getBills();
    _customerPhones = _repository.getCustomerPhones();
  }

  Bill? getById(String id) => _repository.getById(id);

  Future<void> addBill(Bill bill) async {
    await _repository.saveBill(bill);
    _hydrate();
    notifyListeners();
  }

  CustomerContact? getCustomerContactByPhone(String phone) {
    return _repository.getCustomerContactByPhone(phone);
  }

  Future<bool> addOrUpdateCustomerContact({
    required String name,
    required String phone,
  }) async {
    final created = await _repository.addOrUpdateCustomerContact(
      name: name,
      phone: phone,
    );
    _hydrate();
    notifyListeners();
    return created;
  }

  Future<bool> addKnownCustomerPhone(String phone) async {
    final added = await _repository.addKnownCustomerPhone(phone);
    if (!added) return false;
    _hydrate();
    notifyListeners();
    return true;
  }

  bool hasKnownCustomerPhone(String phone) {
    return _repository.hasKnownCustomerPhone(phone);
  }

  List<String> searchCustomerPhones(String query) {
    return _repository.searchCustomerPhones(query);
  }

  List<CustomerContact> searchCustomerContacts(String query) {
    return _repository.searchCustomerContacts(query);
  }
}
