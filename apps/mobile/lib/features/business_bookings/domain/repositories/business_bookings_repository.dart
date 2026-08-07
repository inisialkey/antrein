import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/booking.dart';

/// Operational booking desk (api-contract §65, §68, §68.1, §73).
abstract class BusinessBookingsRepository {
  /// One outlet-day of bookings, newest first (§65).
  ResultFuture<List<Booking>> list({
    required String businessId,
    required String outletId,
    required String date,
  });

  /// Records money taken at the counter (§73). [amount] must equal the booking's
  /// outstanding balance — the backend rejects anything else with
  /// `PAYMENT_AMOUNT_MISMATCH`, so the caller never lets staff type a figure.
  ResultVoid confirmPayAtLocation({
    required String businessId,
    required String bookingId,
    required Money amount,
    required String method,
    required String idempotencyKey,
    String? note,
  });

  /// Business-initiated cancellation (§68.1) — always a full refund (ADR 0040).
  ResultVoid cancel({
    required String businessId,
    required String bookingId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  });

  /// Marks a confirmed booking that never checked in as no-show (§68).
  ResultVoid markNoShow({
    required String businessId,
    required String bookingId,
    required String idempotencyKey,
    String? reason,
  });

  /// Payments recorded against a booking (§70) — the refund flow needs the
  /// payment id and provider, which the booking payload does not carry.
  ResultFuture<List<PaymentInfo>> listPayments(String bookingId);

  /// Business-initiated refund (§74). Asynchronous: a 202 means the provider
  /// was asked, not that money moved — the payment status carries the outcome.
  ResultVoid requestRefund({
    required String businessId,
    required String paymentId,
    required Money amount,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  });
}
