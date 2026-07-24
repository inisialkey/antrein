import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/auth/domain/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class ResetPassword extends UseCase<void, ResetPasswordParams> {
  const ResetPassword(this._repository);

  final AuthRepository _repository;

  @override
  ResultVoid call(ResetPasswordParams params) => _repository.resetPassword(
    token: params.token,
    newPassword: params.newPassword,
  );
}

class ResetPasswordParams extends Equatable {
  const ResetPasswordParams({required this.token, required this.newPassword});

  final String token;
  final String newPassword;

  @override
  List<Object?> get props => [token, newPassword];
}
