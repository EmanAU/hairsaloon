import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
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

  String? get _accountKey {
    final id = LocalAuthSessionDataSource(prefs: _prefs).readUserId();
    return id == null ? null : '$storageKey.$id';
  }

  Future<void> migrateLegacyProfile() async {
    if (_prefs.getBool('profile.scoped.v1') == true) return;
    final key = _accountKey;
    final raw = _prefs.getString(storageKey);
    if (key != null && raw != null && !_prefs.containsKey(key)) {
      await _prefs.setString(key, raw);
      await _prefs.remove(storageKey);
    }
    await _prefs.setBool('profile.scoped.v1', true);
  }

  @override
  Future<BusinessProfile?> getProfile() async {
    final key = _accountKey;
    if (key == null) return null;
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    final model = BusinessProfileModel.fromJsonString(raw);
    return model.toEntity();
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) async {
    final raw = BusinessProfileModel.fromEntity(profile).toJsonString();
    final key = _accountKey;
    if (key == null) throw StateError('Sign in before saving a business.');
    if (!await _prefs.setString(key, raw)) {
      throw StateError('Could not save business profile.');
    }
  }

  @override
  Future<void> clearProfile() async {
    final key = _accountKey;
    if (key != null) await _prefs.remove(key);
  }
}
