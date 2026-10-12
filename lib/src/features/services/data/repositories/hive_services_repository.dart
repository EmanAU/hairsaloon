import 'dart:collection';

import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveServicesRepository {
  HiveServicesRepository({Box<Map>? servicesBox, Box<Map>? categoriesBox})
    : _servicesBox = servicesBox ?? Hive.box<Map>(HiveBoxes.services),
      _categoriesBox = categoriesBox ?? Hive.box<Map>(HiveBoxes.categories);

  final Box<Map> _servicesBox;
  final Box<Map> _categoriesBox;

  static const String _categoryTreeKey = 'category_tree';

  Future<void> ensureSeeded() async {
    if (_categoriesBox.isEmpty) {
      await _categoriesBox.put(_categoryTreeKey, _defaultCategoryTree());
    }
    if (_servicesBox.isEmpty) {
      for (final item in _defaultServices) {
        await _servicesBox.put(item.id, _serviceToMap(item));
      }
    }
  }

  List<String> getCategories() {
    final tree = _readTree();
    return List<String>.unmodifiable(tree.keys);
  }

  List<String> getSubcategoriesFor(String category) {
    final tree = _readTree();
    final values = tree[category] ?? const <String>[];
    return List<String>.unmodifiable(values);
  }

  Future<bool> addSubcategory({
    required String category,
    required String subcategory,
  }) async {
    final normalized = subcategory.trim();
    if (normalized.isEmpty) return false;
    final tree = _readTree();
    final values = tree[category];
    if (values == null) return false;
    final exists = values.any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) return false;
    values.insert(0, normalized);
    await _categoriesBox.put(_categoryTreeKey, _treeToMap(tree));
    return true;
  }

  Future<void> deleteSubcategory({
    required String category,
    required String subcategory,
  }) async {
    final tree = _readTree();
    final values = tree[category];
    if (values == null) return;
    final normalized = subcategory.trim();
    values.removeWhere(
      (item) => item.toLowerCase() == subcategory.trim().toLowerCase(),
    );
    await _categoriesBox.put(_categoryTreeKey, _treeToMap(tree));

    // Also delete all services for this subcategory (price lives on services).
    final services = getServices();
    for (final service in services) {
      if (service.category != category) continue;
      if (service.subcategory.toLowerCase() != normalized.toLowerCase())
        continue;
      await _servicesBox.delete(service.id);
    }
  }

  Future<bool> renameSubcategory({
    required String category,
    required String oldName,
    required String newName,
  }) async {
    final tree = _readTree();
    final values = tree[category];
    if (values == null) return false;

    final normalizedOld = oldName.trim();
    final normalizedNew = newName.trim();
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) return false;

    final index = values.indexWhere(
      (item) => item.toLowerCase() == normalizedOld.toLowerCase(),
    );
    if (index == -1) return false;

    final duplicate = values.any(
      (item) =>
          item.toLowerCase() == normalizedNew.toLowerCase() &&
          item.toLowerCase() != normalizedOld.toLowerCase(),
    );
    if (duplicate) return false;

    values[index] = normalizedNew;
    await _categoriesBox.put(_categoryTreeKey, _treeToMap(tree));
    return true;
  }

  List<ServiceItem> getServices() {
    final values = _servicesBox.values
        .map((item) => _serviceFromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return values;
  }

  ServiceItem? serviceFor({
    required String category,
    required String subcategory,
  }) {
    final services = getServices();
    for (final item in services) {
      if (item.category == category && item.subcategory == subcategory) {
        return item;
      }
    }
    return null;
  }

  Future<void> ensureServicesForCurrentSubcategories() async {
    // IMPORTANT: Subcategories do NOT have prices. Services are added explicitly
    // via Rate List. Historically we auto-created a "service" per subcategory
    // with a seeded/random price — that caused confusing pricing.
    //
    // We now only clean up those legacy auto-created seeded services.
    await _cleanupLegacySeededSubcategoryServices();
  }

  double seededPrice(String category, String subcategory) {
    final hash = (category + subcategory).codeUnits.fold<int>(
      0,
      (value, unit) => value + unit,
    );
    final bucket = hash % 31;
    return (300 + (bucket * 100)).toDouble();
  }

  Future<void> _cleanupLegacySeededSubcategoryServices() async {
    final services = getServices();
    for (final service in services) {
      if (service.gender != 'Other' || service.ageGroup != 'Adult') continue;
      final expected = seededPrice(service.category, service.subcategory);
      if (service.price != expected) continue;
      // Matches the old ID pattern "<micros>_<category>_<subcategory>"
      if (!service.id.endsWith('_${service.category}_${service.subcategory}')) {
        continue;
      }
      await _servicesBox.delete(service.id);
    }
  }

  Future<void> addService(ServiceItem service) async {
    await _servicesBox.put(service.id, _serviceToMap(service));
  }

  Future<void> updateService(ServiceItem service) async {
    await _servicesBox.put(service.id, _serviceToMap(service));
  }

  Future<void> deleteService(String id) async {
    await _servicesBox.delete(id);
  }

  Future<void> renameSubcategoryInServices({
    required String category,
    required String oldName,
    required String newName,
  }) async {
    final services = getServices();
    for (final service in services) {
      if (service.category != category) continue;
      if (service.subcategory.toLowerCase() != oldName.trim().toLowerCase()) {
        continue;
      }
      final updated = service.copyWith(subcategory: newName.trim());
      await _servicesBox.put(updated.id, _serviceToMap(updated));
    }
  }

  Future<void> updatePriceForSubcategory({
    required String category,
    required String subcategory,
    required double price,
  }) async {
    if (price <= 0) return;
    final normalized = subcategory.trim();
    if (normalized.isEmpty) return;

    final services = getServices();
    var updatedAny = false;
    for (final service in services) {
      if (service.category != category) continue;
      if (service.subcategory.toLowerCase() != normalized.toLowerCase())
        continue;
      updatedAny = true;
      final updated = service.copyWith(price: price);
      await _servicesBox.put(updated.id, _serviceToMap(updated));
    }

    if (updatedAny) return;

    // If no service exists yet, create a single canonical service entry.
    // We keep gender/ageGroup stable for billing display.
    final created = ServiceItem(
      id: 'svc_${DateTime.now().microsecondsSinceEpoch}',
      category: category,
      subcategory: normalized,
      gender: 'Other',
      ageGroup: 'Adult',
      price: price,
    );
    await _servicesBox.put(created.id, _serviceToMap(created));
  }

  LinkedHashMap<String, List<String>> _readTree() {
    final raw = _categoriesBox.get(_categoryTreeKey);
    if (raw == null) return _defaultCategoryTree();
    final map = <String, List<String>>{};
    for (final entry in raw.entries) {
      map[entry.key.toString()] = (entry.value as List<dynamic>)
          .map((item) => item.toString())
          .toList(growable: true);
    }
    return LinkedHashMap<String, List<String>>.from(map);
  }
}

Map<String, dynamic> _serviceToMap(ServiceItem item) {
  return <String, dynamic>{
    'id': item.id,
    'category': item.category,
    'subcategory': item.subcategory,
    'gender': item.gender,
    'ageGroup': item.ageGroup,
    'price': item.price,
  };
}

ServiceItem _serviceFromMap(Map<String, dynamic> map) {
  return ServiceItem(
    id: (map['id'] ?? '').toString(),
    category: (map['category'] ?? '').toString(),
    subcategory: (map['subcategory'] ?? '').toString(),
    gender: (map['gender'] ?? '').toString(),
    ageGroup: (map['ageGroup'] ?? '').toString(),
    price: (map['price'] as num?)?.toDouble() ?? 0,
  );
}

Map<String, dynamic> _treeToMap(LinkedHashMap<String, List<String>> tree) {
  return <String, dynamic>{
    for (final entry in tree.entries) entry.key: List<String>.from(entry.value),
  };
}

LinkedHashMap<String, List<String>> _defaultCategoryTree() {
  const categories = <String>[
    'Hair Care & Styling',
    'Nail Care',
    'Skincare & Facials',
    'Hair Removal',
    'Eye & Makeup',
    'Body & Wellness',
    "Men's Grooming",
    'Bridal Services',
    'Kids Services',
    'Spa & Massage',
    'Hair Treatments',
    'Packages',
  ];
  return LinkedHashMap<String, List<String>>.fromEntries(
    categories.map((category) => MapEntry(category, <String>[])),
  )..addAll(<String, List<String>>{
    'Hair Care & Styling': <String>[
      'Simple Cutting',
      'Buzzcuts',
      'Layers Cut',
      'Trims',
    ],
    'Nail Care': <String>['Manicure', 'Pedicure'],
    'Skincare & Facials': <String>['Cleanup', 'Basic Facial'],
    'Hair Removal': <String>['Threading', 'Waxing Arms'],
    'Eye & Makeup': <String>['Eye Makeup', 'Party Makeup'],
    'Body & Wellness': <String>['Body Polish'],
    "Men's Grooming": <String>['Beard Trim', 'Shave'],
    'Bridal Services': <String>['Bridal Makeup'],
    'Kids Services': <String>['Kids Hair Cut'],
    'Spa & Massage': <String>['Head Massage'],
    'Hair Treatments': <String>['Hair Spa', 'Keratin'],
    'Packages': <String>['Groom Package', 'Bridal Package'],
  });
}

const List<ServiceItem> _defaultServices = <ServiceItem>[
  ServiceItem(
    id: '1',
    category: 'Hair Care & Styling',
    subcategory: 'Simple Cutting',
    gender: 'Male',
    ageGroup: 'Adult',
    price: 400,
  ),
  ServiceItem(
    id: '2',
    category: "Men's Grooming",
    subcategory: 'Beard Trim',
    gender: 'Male',
    ageGroup: 'Adult',
    price: 350,
  ),
  ServiceItem(
    id: '3',
    category: "Men's Grooming",
    subcategory: 'Shave',
    gender: 'Male',
    ageGroup: 'Adult',
    price: 300,
  ),
  ServiceItem(
    id: '4',
    category: 'Skincare & Facials',
    subcategory: 'Basic Facial',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 1500,
  ),
  ServiceItem(
    id: '5',
    category: 'Skincare & Facials',
    subcategory: 'Cleanup',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 2200,
  ),
  ServiceItem(
    id: '6',
    category: 'Hair Treatments',
    subcategory: 'Keratin',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 2500,
  ),
  ServiceItem(
    id: '7',
    category: 'Hair Treatments',
    subcategory: 'Hair Spa',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 1800,
  ),
  ServiceItem(
    id: '8',
    category: 'Packages',
    subcategory: 'Groom Package',
    gender: 'Male',
    ageGroup: 'Adult',
    price: 2800,
  ),
  ServiceItem(
    id: '9',
    category: 'Packages',
    subcategory: 'Bridal Package',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 8500,
  ),
  ServiceItem(
    id: '10',
    category: 'Kids Services',
    subcategory: 'Kids Hair Cut',
    gender: 'Male',
    ageGroup: 'Child',
    price: 500,
  ),
  ServiceItem(
    id: '11',
    category: 'Hair Removal',
    subcategory: 'Threading',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 300,
  ),
  ServiceItem(
    id: '12',
    category: 'Hair Removal',
    subcategory: 'Waxing Arms',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 1200,
  ),
  ServiceItem(
    id: '13',
    category: 'Skincare & Facials',
    subcategory: 'Cleanup',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 900,
  ),
  ServiceItem(
    id: '14',
    category: 'Hair Care & Styling',
    subcategory: 'Trims',
    gender: 'Female',
    ageGroup: 'Adult',
    price: 700,
  ),
];
