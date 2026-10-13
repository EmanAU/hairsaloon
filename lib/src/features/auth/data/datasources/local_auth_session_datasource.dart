import 'package:shared_preferences/shared_preferences.dart';

/// Persists the signed-in user id on device until explicit logout.
class LocalAuthSessionDataSource {
  LocalAuthSessionDataSource({required SharedPreferences prefs})
    : _prefs = prefs;

  static const _userIdKey = 'auth.current_user_id.v1';

  final SharedPreferences _prefs;

  String? readUserId() {
    final id = _prefs.getString(_userIdKey);
    if (id == null || id.trim().isEmpty) return null;
    return id;
  }

  Future<void> writeUserId(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw StateError('Cannot save an empty auth session.');
    }
    final saved = await _prefs.setString(_userIdKey, trimmed);
    if (!saved) {
      throw StateError('Could not keep you signed in on this device.');
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_userIdKey);
  }
}
