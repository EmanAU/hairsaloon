import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hairsaloon/src/features/billing/data/repositories/hive_billing_repository.dart';

void main() {
  test(
    'local and international phone formats reuse new and legacy customers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'customer_phone_identity',
      );
      Hive.init(directory.path);
      final bills = await Hive.openBox<Map>('bills');
      final phones = await Hive.openBox<String>('phones');
      final contacts = await Hive.openBox<Map>('contacts');
      final repository = HiveBillingRepository(
        billsBox: bills,
        phonesBox: phones,
        contactsBox: contacts,
      );
      try {
        await repository.addOrUpdateCustomerContact(
          name: 'New customer',
          phone: '+923001234567',
        );
        for (final phone in [
          '03001234567',
          '+923001234567',
          '923001234567',
          '00923001234567',
        ]) {
          expect(repository.hasKnownCustomerPhone(phone), isTrue);
          expect(
            repository.getCustomerContactByPhone(phone)?.name,
            'New customer',
          );
          expect(await repository.addKnownCustomerPhone(phone), isFalse);
        }
        await repository.addOrUpdateCustomerContact(
          name: 'Updated',
          phone: '03001234567',
        );
        expect(contacts.length, 1);
        expect(phones.length, 1);
        expect(
          repository.searchCustomerContacts('0300').single.name,
          'Updated',
        );
        expect(repository.searchCustomerPhones('0300'), hasLength(1));
        // Old installations stored raw local keys. They must remain readable/updatable.
        await contacts.put('03001234568', {
          'name': 'Legacy',
          'phone': '03001234568',
        });
        await phones.put('03001234568', '03001234568');
        expect(
          repository.getCustomerContactByPhone('+923001234568')?.name,
          'Legacy',
        );
        expect(repository.hasKnownCustomerPhone('+923001234568'), isTrue);
        await repository.addOrUpdateCustomerContact(
          name: 'Legacy updated',
          phone: '+923001234568',
        );
        expect(contacts.length, 2);
        expect(phones.length, 2);
        expect(
          repository.getCustomerContactByPhone('03001234568')?.name,
          'Legacy updated',
        );
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
