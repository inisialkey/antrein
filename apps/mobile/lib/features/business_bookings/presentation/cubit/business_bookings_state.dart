part of 'business_bookings_cubit.dart';

enum BookingDeskStatus { initial, loading, success, empty, failure }

/// Which mutation just landed — the page turns it into a snackbar.
enum BookingDeskAction { paymentConfirmed, cancelled, noShow }

/// Pay-at-location methods (api-contract §73, `PAY_AT_LOCATION_METHODS`).
const List<String> payAtLocationMethods = [
  'cash',
  'qris_manual',
  'bank_transfer_manual',
  'card_terminal',
  'other',
];

@freezed
abstract class BusinessBookingsState with _$BusinessBookingsState {
  const BusinessBookingsState._();

  const factory BusinessBookingsState({
    @Default(BookingDeskStatus.initial) BookingDeskStatus status,
    @Default(<Booking>[]) List<Booking> bookings,
    DateTime? date,
    @Default(false) bool isRefreshing,
    String? message,
    String? actingBookingId,
    String? actionError,
    BookingDeskAction? actionDone,
  }) = _BusinessBookingsState;

  /// Live lookup for the detail sheet, which holds an id rather than a copy so
  /// it reflects every resync.
  Booking? bookingById(String id) {
    for (final booking in bookings) {
      if (booking.id == id) return booking;
    }
    return null;
  }
}
