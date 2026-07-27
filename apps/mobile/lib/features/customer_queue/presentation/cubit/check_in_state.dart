part of 'check_in_cubit.dart';

@freezed
sealed class CheckInState with _$CheckInState {
  const factory CheckInState.initial() = CheckInInitial;
  const factory CheckInState.submitting() = CheckInSubmitting;
  const factory CheckInState.success(QueueEntry entry) = CheckInSuccess;
  const factory CheckInState.error(String message, {String? code}) =
      CheckInError;
}
