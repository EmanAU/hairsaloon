import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
import 'package:hairsaloon/src/features/auth/domain/entities/app_user.dart';
import 'package:hairsaloon/src/features/auth/domain/repositories/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({
    required SharedPreferences prefs,
    required LocalAuthSessionDataSource session,
  }) : _prefs = prefs,
       _session = session;

  static const _accountsKey = 'auth.local_accounts.v1';
  final SharedPreferences _prefs;
  final LocalAuthSessionDataSource _session;

  Map<String, dynamic> _accounts() =>
      jsonDecode(_prefs.getString(_accountsKey) ?? '{}')
          as Map<String, dynamic>;
  String _phone(String phone) {
    var value = phone.replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('0092')) value = '+${value.substring(2)}';
    if (RegExp(r'^03\d{9}$').hasMatch(value)) {
      value = '+92${value.substring(1)}';
    }
    if (RegExp(r'^92\d{10}$').hasMatch(value)) value = '+$value';
    return value;
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
  AppUser _user(Map<String, dynamic> data) => AppUser(
    id: data['id'] as String,
    name: data['name'] as String,
    username: data['username'] as String,
    phone: data['phone'] as String,
    createdAt: DateTime.parse(data['createdAt'] as String),
  );

  @override
  Future<AppUser?> getCurrentUser() async {
    final id = _session.readUserId();
    for (final record in _accounts().values) {
      final data = record as Map<String, dynamic>;
      if (data['id'] == id) return _user(data);
    }
    return null;
  }

  @override
  Future<bool> hasSession() async => await getCurrentUser() != null;

  @override
  Future<AppUser> registerUser({
    required String name,
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = _phone(phone);
    if (name.trim().isEmpty ||
        !RegExp(r'^\+92\d{10}$').hasMatch(normalizedPhone) ||
        password.length < 6) {
      throw const FormatException(
        'Enter a name, an 11-digit phone number starting with 03 and password of at least 6 characters.',
      );
    }
    final accounts = _accounts();
    if (accounts.containsKey(normalizedPhone)) {
      throw StateError(
        'An account with this phone already exists on this device.',
      );
    }
    final random = Random.secure();
    final salt = base64Url.encode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final id = base64Url.encode(List.generate(18, (_) => random.nextInt(256)));
    final data = <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'username': 'user_$id',
      'phone': normalizedPhone,
      'createdAt': DateTime.now().toIso8601String(),
      'salt': salt,
      'passwordHash': _hash(password, salt),
    };
    accounts[normalizedPhone] = data;
    if (!await _prefs.setString(_accountsKey, jsonEncode(accounts))) {
      throw StateError('Could not save the local account.');
    }
    await _session.writeUserId(id);
    return _user(data);
  }

  @override
  Future<AppUser> loginWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    final data = _accounts()[_phone(phone)] as Map<String, dynamic>?;
    if (data == null ||
        data['passwordHash'] != _hash(password, data['salt'] as String)) {
      throw StateError('Incorrect phone number or password.');
    }
    await _session.writeUserId(data['id'] as String);
    return _user(data);
  }

  @override
  Future<void> logout() => _session.clear();
}
