part of 'password_reset_cubit.dart';

@freezed
sealed class PasswordResetState with _$PasswordResetState {
  const factory PasswordResetState.initial() = PasswordResetInitial;
  const factory PasswordResetState.loading() = PasswordResetLoading;
  const factory PasswordResetState.success() = PasswordResetSuccess;
  const factory PasswordResetState.error(String message) = PasswordResetError;
}
