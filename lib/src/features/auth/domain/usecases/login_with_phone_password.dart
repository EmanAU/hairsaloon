import 'package:hairsaloon/src/features/auth/domain/entities/app_user.dart';
import 'package:hairsaloon/src/features/auth/domain/repositories/auth_repository.dart';

class LoginWithPhonePassword {
  const LoginWithPhonePassword(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({required String phone, required String password}) {
    return _repository.loginWithPhonePassword(phone: phone, password: password);
  }
}
