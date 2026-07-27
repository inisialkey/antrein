part of 'my_bookings_cubit.dart';

enum MyBookingsStatus { initial, loading, success, empty, failure }

@freezed
sealed class MyBookingsState with _$MyBookingsState {
  const factory MyBookingsState({
    required MyBookingsStatus status,
    @Default(<Booking>[]) List<Booking> bookings,
    @Default(false) bool isRefreshing,
    String? message,
  }) = _MyBookingsState;
}
