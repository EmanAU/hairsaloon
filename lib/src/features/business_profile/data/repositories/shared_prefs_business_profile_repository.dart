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
  static const _scopedFlagKey = 'profile.scoped.v1';

  final SharedPreferences _prefs;

  String? get _accountKey {
    final id = LocalAuthSessionDataSource(prefs: _prefs).readUserId();
    return id == null ? null : '$storageKey.$id';
  }

  Future<void> migrateLegacyProfile() async {
    final key = _accountKey;
    final legacy = _prefs.getString(storageKey);
    final hasLegacy = legacy != null && legacy.trim().isNotEmpty;

    // Session not ready yet — keep the flag unset so a later boot can migrate.
    if (key == null) {
      if (!hasLegacy) {
        await _prefs.setBool(_scopedFlagKey, true);
      }
      return;
    }

    if (hasLegacy && !_prefs.containsKey(key)) {
      await _prefs.setString(key, legacy);
    }
    if (hasLegacy) {
      await _prefs.remove(storageKey);
    }
    await _prefs.setBool(_scopedFlagKey, true);
  }

  @override
  Future<BusinessProfile?> getProfile() async {
    final key = _accountKey;
    if (key == null) return null;

    var raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      // Recover profiles left under the pre-scoping key (or after a migrate
      // that ran before the auth session was available).
      raw = await _recoverLegacyProfile(key);
    }
    if (raw == null || raw.trim().isEmpty) return null;

    final model = BusinessProfileModel.fromJsonString(raw);
    return model.toEntity();
  }

  Future<String?> _recoverLegacyProfile(String scopedKey) async {
    final legacy = _prefs.getString(storageKey);
    if (legacy == null || legacy.trim().isEmpty) return null;
    await _prefs.setString(scopedKey, legacy);
    await _prefs.remove(storageKey);
    await _prefs.setBool(_scopedFlagKey, true);
    return legacy;
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) async {
    final raw = BusinessProfileModel.fromEntity(profile).toJsonString();
    final key = _accountKey;
    if (key == null) throw StateError('Sign in before saving a business.');
    if (!await _prefs.setString(key, raw)) {
      throw StateError('Could not save business profile.');
    }
    // Drop any leftover unscoped copy so restarts always read the scoped key.
    if (_prefs.containsKey(storageKey)) {
      await _prefs.remove(storageKey);
    }
    await _prefs.setBool(_scopedFlagKey, true);
  }

  @override
  Future<void> clearProfile() async {
    final key = _accountKey;
    if (key != null) await _prefs.remove(key);
  }
}
