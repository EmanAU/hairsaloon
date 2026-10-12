import 'package:hairsaloon/src/features/business_profile/data/models/business_profile_model.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/repositories/business_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsBusinessProfileRepository
    implements BusinessProfileRepository {
  SharedPrefsBusinessProfileRepository({required SharedPreferences prefs})
    : _prefs = prefs;

  static const storageKey = 'business_profile_v1';

  final SharedPreferences _prefs;

  @override
  Future<BusinessProfile?> getProfile() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final model = BusinessProfileModel.fromJsonString(raw);
    return model.toEntity();
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) async {
    final raw = BusinessProfileModel.fromEntity(profile).toJsonString();
    await _prefs.setString(storageKey, raw);
  }

  @override
  Future<void> clearProfile() async {
    await _prefs.remove(storageKey);
  }
}
