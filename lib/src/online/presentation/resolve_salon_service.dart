import '../data/business_workspace.dart';
import '../domain/online_models.dart';

/// Finds the online [SalonService] for a local category + subcategory name.
/// Seeds defaults if needed; creates a row when the rate-list item is new.
/// Always prefers an existing row (with saved customer view) — never duplicates.
Future<SalonService> resolveSalonService({
  required BusinessWorkspace workspace,
  required String category,
  required String subcategory,
  required double price,
}) async {
  final businessId = workspace.business.id;
  final repository = workspace.repository;

  try {
    await repository.ensureBusinessServices(businessId);
  } catch (_) {
    // Best-effort seed; continue with whatever exists.
  }

  SalonService? match(List<SalonService> services) {
    final cat = category.trim().toLowerCase();
    final name = subcategory.trim().toLowerCase();
    SalonService? withContent;
    SalonService? any;
    for (final service in services) {
      final sameCategory = service.category.trim().toLowerCase() == cat;
      final sameName = service.name.trim().toLowerCase() == name;
      if (!sameCategory || !sameName) continue;
      any ??= service;
      if (service.hasRichContent) {
        withContent ??= service;
      }
    }
    // Resume the row that already has customer-view content when duplicates exist.
    return withContent ?? any;
  }

  var services = await repository.services(
    businessId,
    includeInactive: true,
  );
  final existing = match(services);
  if (existing != null) {
    // Re-fetch by id so content_json is the latest from Supabase.
    final fresh = await repository.serviceById(existing.id);
    return fresh ?? existing;
  }

  final created = await repository.saveService(
    businessId: businessId,
    name: subcategory.trim(),
    category: category.trim(),
    description: '',
    price: price < 0 ? 0 : price,
    isActive: true,
  );
  return created;
}
