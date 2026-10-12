import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/auth/domain/entities/app_user.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/get_current_user.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/has_session.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/login_with_phone_password.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/logout.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/register_user.dart';

class AuthStore extends ChangeNotifier {
  AuthStore({
    required HasSession hasSession,
    required GetCurrentUser getCurrentUser,
    required RegisterUser registerUser,
    required LoginWithPhonePassword loginWithPhonePassword,
    required Logout logout,
  }) : _hasSession = hasSession,
       _getCurrentUser = getCurrentUser,
       _registerUser = registerUser,
       _loginWithPhonePassword = loginWithPhonePassword,
       _logout = logout;

  final HasSession _hasSession;
  final GetCurrentUser _getCurrentUser;
  final RegisterUser _registerUser;
  final LoginWithPhonePassword _loginWithPhonePassword;
  final Logout _logout;

  bool _isLoading = false;
  String? _error;
  AppUser? _currentUser;

  bool get isLoading => _isLoading;
  String? get error => _error;
  AppUser? get currentUser => _currentUser;

  Future<bool> hasLocalSession() => _hasSession();

  Future<void> loadCurrentUser() async {
    _setLoading(true);
    try {
      _currentUser = await _getCurrentUser();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startRegistration({
    required String name,
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _registerUser(
        name: name,
        phone: phone,
        password: password,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login({required String phone, required String password}) async {
    _setLoading(true);
    try {
      _currentUser = await _loginWithPhonePassword(
        phone: phone,
        password: password,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _logout();
      _currentUser = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
