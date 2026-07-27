part of 'booking_detail_cubit.dart';

enum BookingDetailStatus { initial, loading, success, failure }

@freezed
sealed class BookingDetailState with _$BookingDetailState {
  const factory BookingDetailState({
    required BookingDetailStatus status,
    Booking? booking,
    PaymentInfo? pendingPayment,
    @Default(false) bool isCancelling,
    @Default(false) bool isRefreshingPayment,
    @Default(false) bool didCancel,
    String? message,
  }) = _BookingDetailState;
}
