part of 'create_booking_cubit.dart';

@freezed
sealed class CreateBookingState with _$CreateBookingState {
  const factory CreateBookingState.idle() = CreateBookingIdle;
  const factory CreateBookingState.submitting() = CreateBookingSubmitting;
  const factory CreateBookingState.success(BookingCreation creation) =
      CreateBookingSuccess;
  const factory CreateBookingState.error(
    String message, {
    String? code,
    @Default(false) bool retryable,
  }) = CreateBookingError;
}
