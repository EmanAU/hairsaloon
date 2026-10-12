import 'package:hairsaloon/src/features/auth/domain/entities/app_user.dart';
import 'package:hairsaloon/src/features/auth/domain/repositories/auth_repository.dart';

class RegisterUser {
  const RegisterUser(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String name,
    required String phone,
    required String password,
  }) {
    return _repository.registerUser(
      name: name,
      phone: phone,
      password: password,
    );
  }
}
