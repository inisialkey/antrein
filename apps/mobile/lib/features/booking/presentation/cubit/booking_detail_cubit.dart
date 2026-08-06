import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/entities/payment_info.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:antrein/features/booking/domain/usecases/cancel_booking.dart';
import 'package:antrein/features/booking/domain/usecases/get_booking.dart';
import 'package:antrein/features/booking/domain/usecases/refresh_payment.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'booking_detail_cubit.freezed.dart';
part 'booking_detail_state.dart';

/// Booking detail: load, cancel, and — while awaiting payment — refresh the
/// payment status against the provider (§72). Action flags keep the loaded
/// booking on screen during mutations.
@injectable
class BookingDetailCubit extends Cubit<BookingDetailState> {
  BookingDetailCubit(
    this._getBooking,
    this._cancelBooking,
    this._refreshPayment,
    this._repository,
  ) : super(const BookingDetailState(status: BookingDetailStatus.initial));

  final GetBooking _getBooking;
  final CancelBooking _cancelBooking;
  final RefreshPayment _refreshPayment;
  final BookingRepository _repository;

  Future<void> load(String bookingId) async {
    emit(state.copyWith(status: BookingDetailStatus.loading));
    final result = await _getBooking(GetBookingParams(bookingId: bookingId));
    await result.match(
      (failure) async => emit(
        state.copyWith(
          status: BookingDetailStatus.failure,
          message: failure.message,
        ),
      ),
      (booking) async {
        PaymentInfo? pending;
        if (booking.isAwaitingPayment) {
          final payments = await _repository.listBookingPayments(booking.id);
          final list = payments.getOrElse((_) => const <PaymentInfo>[]);
          for (final p in list) {
            if (p.isPending) {
              pending = p;
              break;
            }
          }
        }
        emit(
          state.copyWith(
            status: BookingDetailStatus.success,
            booking: booking,
            pendingPayment: pending,
            message: null,
          ),
        );
      },
    );
  }

  Future<void> cancel({String? reasonCode, String? reason}) async {
    final booking = state.booking;
    if (booking == null || state.isCancelling) return;
    emit(state.copyWith(isCancelling: true));
    final result = await _cancelBooking(
      CancelBookingParams(
        bookingId: booking.id,
        idempotencyKey: newIdempotencyKey(),
        reasonCode: reasonCode,
        reason: reason,
      ),
    );
    result.match(
      (failure) => emit(
        state.copyWith(isCancelling: false, message: failure.message),
      ),
      (updated) => emit(
        state.copyWith(
          isCancelling: false,
          booking: updated,
          pendingPayment: null,
          message: null,
          didCancel: true,
        ),
      ),
    );
  }

  /// Poll the payment provider for a stale pending_payment screen (§72).
  Future<void> refreshPaymentStatus() async {
    final booking = state.booking;
    final payment = state.pendingPayment;
    if (booking == null || payment == null || state.isRefreshingPayment) return;
    emit(state.copyWith(isRefreshingPayment: true));
    final result = await _refreshPayment(
      RefreshPaymentParams(paymentId: payment.id),
    );
    await result.match(
      (failure) async => emit(
        state.copyWith(isRefreshingPayment: false, message: failure.message),
      ),
      (refresh) async {
        emit(state.copyWith(isRefreshingPayment: false));
        if (refresh.bookingStatus != booking.status) {
          await load(booking.id);
        }
      },
    );
  }
}
