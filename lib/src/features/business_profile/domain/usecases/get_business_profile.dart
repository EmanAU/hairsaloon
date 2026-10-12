import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/repositories/business_profile_repository.dart';

class GetBusinessProfile {
  const GetBusinessProfile(this._repository);

  final BusinessProfileRepository _repository;

  Future<BusinessProfile?> call() => _repository.getProfile();
}
