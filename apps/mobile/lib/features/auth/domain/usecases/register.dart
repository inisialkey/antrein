import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/auth/domain/entities/user.dart';
import 'package:antrein/features/auth/domain/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class Register extends UseCase<User, RegisterParams> {
  const Register(this._repository);

  final AuthRepository _repository;

  @override
  ResultFuture<User> call(RegisterParams params) => _repository.register(
    name: params.name,
    email: params.email,
    password: params.password,
    phoneNumber: params.phoneNumber,
  );
}

class RegisterParams extends Equatable {
  const RegisterParams({
    required this.name,
    required this.email,
    required this.password,
    this.phoneNumber,
  });

  final String name;
  final String email;
  final String password;
  final String? phoneNumber;

  @override
  List<Object?> get props => [name, email, password, phoneNumber];
}
