import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/auth/domain/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class RequestPasswordReset extends UseCase<void, RequestPasswordResetParams> {
  const RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  @override
  ResultVoid call(RequestPasswordResetParams params) =>
      _repository.requestPasswordReset(email: params.email);
}

class RequestPasswordResetParams extends Equatable {
  const RequestPasswordResetParams({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}
