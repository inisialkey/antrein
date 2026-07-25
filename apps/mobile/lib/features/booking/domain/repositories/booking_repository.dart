import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/entities/payment_info.dart';
import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:equatable/equatable.dart';

/// Result of booking creation (§60): the booking plus, for online payment
/// options, the pending payment with its checkout link.
class BookingCreation extends Equatable {
  const BookingCreation({required this.booking, this.payment});

  final Booking booking;
  final PaymentInfo? payment;

  @override
  List<Object?> get props => [booking, payment];
}

/// Result of a payment refresh (§72).
class PaymentRefreshResult extends Equatable {
  const PaymentRefreshResult({
    required this.paymentStatus,
    required this.bookingStatus,
    required this.refreshedFromProvider,
  });

  final String paymentStatus;
  final BookingStatus bookingStatus;
  final bool refreshedFromProvider;

  @override
  List<Object?> get props => [
    paymentStatus,
    bookingStatus,
    refreshedFromProvider,
  ];
}

abstract class BookingRepository {
  ResultFuture<List<Slot>> getAvailability({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required String date,
  });

  ResultFuture<BookingCreation> createBooking({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required DateTime scheduledAt,
    required String paymentOption,
    required String idempotencyKey,
    String? notes,
  });

  ResultFuture<List<Booking>> listMyBookings({String? status});

  ResultFuture<Booking> getBooking(String bookingId);

  ResultFuture<Booking> cancelBooking({
    required String bookingId,
    required String idempotencyKey,
    String? reasonCode,
    String? reason,
  });

  ResultFuture<PaymentRefreshResult> refreshPayment(String paymentId);

  ResultFuture<List<PaymentInfo>> listBookingPayments(String bookingId);
}
