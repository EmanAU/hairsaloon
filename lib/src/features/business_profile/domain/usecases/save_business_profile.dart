import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/repositories/business_profile_repository.dart';

class SaveBusinessProfile {
  const SaveBusinessProfile(this._repository);

  final BusinessProfileRepository _repository;

  Future<void> call(BusinessProfile profile) =>
      _repository.saveProfile(profile);
}
