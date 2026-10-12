import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';

abstract class BusinessProfileRepository {
  Future<void> saveProfile(BusinessProfile profile);
  Future<BusinessProfile?> getProfile();
  Future<void> clearProfile();
}
