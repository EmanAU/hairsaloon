import '../data/business_workspace.dart';
import '../domain/online_models.dart';

/// Finds the online [SalonService] for a local category + subcategory name.
/// Seeds defaults if needed; creates a row when the rate-list item is new.
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
    for (final service in services) {
      if (service.category.trim().toLowerCase() == category.trim().toLowerCase() &&
          service.name.trim().toLowerCase() == subcategory.trim().toLowerCase()) {
        return service;
      }
    }
    return null;
  }

  var services = await repository.services(
    businessId,
    includeInactive: true,
  );
  final existing = match(services);
  if (existing != null) return existing;

  await repository.saveService(
    businessId: businessId,
    name: subcategory.trim(),
    category: category.trim(),
    description: '',
    price: price < 0 ? 0 : price,
    isActive: true,
  );

  services = await repository.services(businessId, includeInactive: true);
  final created = match(services);
  if (created != null) return created;

  throw const OnlineFailure(
    'Could not open customer view for this service. Try again.',
  );
}
