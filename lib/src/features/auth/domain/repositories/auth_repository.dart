import 'package:hairsaloon/src/features/auth/domain/entities/app_user.dart';

abstract class AuthRepository {
  Future<bool> hasSession();
  Future<AppUser?> getCurrentUser();

  Future<AppUser> registerUser({
    required String name,
    required String phone,
    required String password,
  });

  Future<AppUser> loginWithPhonePassword({
    required String phone,
    required String password,
  });

  Future<void> logout();
}
