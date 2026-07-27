import 'package:antrein/features/auth/domain/usecases/request_password_reset.dart';
import 'package:antrein/features/auth/domain/usecases/reset_password.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'password_reset_cubit.freezed.dart';
part 'password_reset_state.dart';

/// Drives the two-step password-reset flow (request email → confirm with token).
/// Page-scoped (a factory), separate from `AuthCubit` because completing a reset
/// does NOT sign the user in — the backend revokes all sessions, so the user
/// returns to sign-in afterwards.
@injectable
class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._requestReset, this._resetPassword)
    : super(const PasswordResetState.initial());

  final RequestPasswordReset _requestReset;
  final ResetPassword _resetPassword;

  Future<void> requestReset({required String email}) async {
    emit(const PasswordResetState.loading());
    final result = await _requestReset(
      RequestPasswordResetParams(email: email),
    );
    result.match(
      (failure) => emit(PasswordResetState.error(failure.message)),
      (_) => emit(const PasswordResetState.success()),
    );
  }

  Future<void> confirmReset({
    required String token,
    required String newPassword,
  }) async {
    emit(const PasswordResetState.loading());
    final result = await _resetPassword(
      ResetPasswordParams(token: token, newPassword: newPassword),
    );
    result.match(
      (failure) => emit(PasswordResetState.error(failure.message)),
      (_) => emit(const PasswordResetState.success()),
    );
  }
}
