import 'package:hairsaloon/src/features/business_profile/domain/repositories/business_profile_repository.dart';

class ClearBusinessProfile {
  const ClearBusinessProfile(this._repository);

  final BusinessProfileRepository _repository;

  Future<void> call() => _repository.clearProfile();
}
