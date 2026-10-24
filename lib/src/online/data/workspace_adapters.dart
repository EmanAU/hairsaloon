import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/business_profile/domain/entities/business_profile.dart';
import '../../features/business_profile/domain/repositories/business_profile_repository.dart';
import '../domain/online_models.dart';
import 'business_workspace.dart';

class WorkspaceAuth extends AuthRepository {
  WorkspaceAuth(this.workspace);
  final BusinessWorkspace workspace;
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<AppUser?> getCurrentUser() async => AppUser(
    id: workspace.account.id,
    name: workspace.account.name,
    username: workspace.account.name,
    phone: workspace.journal.get('personal_phone') as String? ?? '',
    createdAt: DateTime(2000),
  );
  @override
  Future<void> logout() => workspace.repository.signOut();
  @override
  Future<AppUser> registerUser({
    required String name,
    required String phone,
    required String password,
  }) async =>
      throw const OnlineFailure('Use Google sign-in from the online app.');
  @override
  Future<AppUser> loginWithPhonePassword({
    required String phone,
    required String password,
  }) async =>
      throw const OnlineFailure('Use Google sign-in from the online app.');
}

class WorkspaceProfile extends BusinessProfileRepository {
  WorkspaceProfile(this.workspace);
  final BusinessWorkspace workspace;
  @override
  Future<BusinessProfile?> getProfile() async {
    final business = workspace.business;
    final saved = workspace.settings.get('business_profile') as Map?;
    return BusinessProfile(
      businessName: saved?['name'] as String? ?? business.name,
      phoneNumber: saved?['phone'] as String? ?? business.phone,
      businessType: saved?['type'] as String? ?? business.type,
      city: saved?['city'] as String? ?? business.city,
      area: saved?['area'] as String? ?? business.area,
      address: saved?['address'] as String? ?? business.address,
      logoBase64: saved?['logo'] as String?,
    );
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) =>
      workspace.settings.put('business_profile', {
        'name': profile.businessName,
        'phone': profile.phoneNumber,
        'type': profile.businessType,
        'city': profile.city,
        'area': profile.area,
        'address': profile.address,
        'logo': profile.logoBase64,
      });
  @override
  Future<void> clearProfile() => workspace.settings.delete('business_profile');
}
