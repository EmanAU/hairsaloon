import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthSessionDataSource {
  LocalAuthSessionDataSource({required SharedPreferences prefs})
    : _prefs = prefs;

  static const _userIdKey = 'auth.current_user_id.v1';

  final SharedPreferences _prefs;

  String? readUserId() => _prefs.getString(_userIdKey);

  Future<void> writeUserId(String userId) =>
      _prefs.setString(_userIdKey, userId);

  Future<void> clear() => _prefs.remove(_userIdKey);
}
