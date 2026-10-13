import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/services/data/repositories/hive_services_repository.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';

class ServicesStore extends ChangeNotifier {
  ServicesStore({required HiveServicesRepository repository})
    : _repository = repository;

  final HiveServicesRepository _repository;

  bool _loaded = false;
  bool _loading = false;
  List<ServiceItem> _services = const <ServiceItem>[];
  List<String> _categories = const <String>[];
  final Map<String, List<String>> _subcategoriesByCategory =
      <String, List<String>>{};

  List<ServiceItem> get services => _services;
  List<String> get categories => _categories;
  bool get isLoaded => _loaded;

  /// Safe to call many times; only the first load hits storage.
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await load();
  }

  Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      await _repository.ensureSeeded();
      await _repository.ensureServicesForCurrentSubcategories();
      _hydrate();
      _loaded = true;
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  void _hydrate() {
    _services = _repository.getServices();
    _categories = _repository.getCategories();
    _subcategoriesByCategory.clear();
    for (final category in _categories) {
      _subcategoriesByCategory[category] = _repository.getSubcategoriesFor(
        category,
      );
    }
  }

  List<String> subcategoriesFor(String category) {
    return _subcategoriesByCategory[category] ?? const <String>[];
  }

  ServiceItem? serviceFor({
    required String category,
    required String subcategory,
  }) {
    return _repository.serviceFor(category: category, subcategory: subcategory);
  }

  double seededPrice(String category, String subcategory) {
    return _repository.seededPrice(category, subcategory);
  }

  Future<bool> addCategory(String category) async {
    final added = await _repository.addCategory(category);
    if (!added) return false;
    _hydrate();
    notifyListeners();
    return true;
  }

  Future<bool> renameCategory({
    required String oldName,
    required String newName,
  }) async {
    final renamed = await _repository.renameCategory(
      oldName: oldName,
      newName: newName,
    );
    if (!renamed) return false;
    _hydrate();
    notifyListeners();
    return true;
  }

  Future<void> deleteCategory(String category) async {
    await _repository.deleteCategory(category);
    _hydrate();
    notifyListeners();
  }

  Future<bool> addSubcategory({
    required String category,
    required String subcategory,
  }) async {
    final added = await _repository.addSubcategory(
      category: category,
      subcategory: subcategory,
    );
    if (!added) return false;
    await _repository.ensureServicesForCurrentSubcategories();
    _hydrate();
    notifyListeners();
    return true;
  }

  Future<void> deleteSubcategory({
    required String category,
    required String subcategory,
  }) async {
    await _repository.deleteSubcategory(
      category: category,
      subcategory: subcategory,
    );
    _hydrate();
    notifyListeners();
  }

  Future<bool> renameSubcategory({
    required String category,
    required String oldName,
    required String newName,
  }) async {
    final renamed = await _repository.renameSubcategory(
      category: category,
      oldName: oldName,
      newName: newName,
    );
    if (!renamed) return false;
    await _repository.renameSubcategoryInServices(
      category: category,
      oldName: oldName,
      newName: newName,
    );
    _hydrate();
    notifyListeners();
    return true;
  }

  Future<void> addService(ServiceItem service) async {
    await _repository.addService(service);
    _hydrate();
    notifyListeners();
  }

  Future<void> updateService(ServiceItem service) async {
    await _repository.updateService(service);
    _hydrate();
    notifyListeners();
  }

  Future<void> deleteService(String id) async {
    await _repository.deleteService(id);
    _hydrate();
    notifyListeners();
  }

  Future<void> updatePriceForSubcategory({
    required String category,
    required String subcategory,
    required double price,
  }) async {
    await _repository.updatePriceForSubcategory(
      category: category,
      subcategory: subcategory,
      price: price,
    );
    _hydrate();
    notifyListeners();
  }
}
