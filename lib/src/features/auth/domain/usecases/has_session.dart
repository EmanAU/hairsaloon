import 'package:hairsaloon/src/features/auth/domain/repositories/auth_repository.dart';

class HasSession {
  const HasSession(this._repository);

  final AuthRepository _repository;

  Future<bool> call() => _repository.hasSession();
}
