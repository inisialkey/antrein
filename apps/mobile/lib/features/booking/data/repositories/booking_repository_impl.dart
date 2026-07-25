import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/entities/payment_info.dart';
import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BookingRepository)
class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._remote);

  final BookingRemoteDataSource _remote;

  @override
  ResultFuture<List<Slot>> getAvailability({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required String date,
  }) => _guard('getAvailability', () async {
    final models = await _remote.getAvailability(
      businessId: businessId,
      outletId: outletId,
      serviceId: serviceId,
      staffId: staffId,
      date: date,
    );
    return models.map((m) => m.toEntity()).toList(growable: false);
  });

  @override
  ResultFuture<BookingCreation> createBooking({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required DateTime scheduledAt,
    required String paymentOption,
    required String idempotencyKey,
    String? notes,
  }) => _guard('createBooking', () async {
    final result = await _remote.createBooking(
      businessId: businessId,
      outletId: outletId,
      serviceId: serviceId,
      staffId: staffId,
      scheduledAt: scheduledAt.toUtc().toIso8601String(),
      paymentOption: paymentOption,
      idempotencyKey: idempotencyKey,
      notes: notes,
    );
    return BookingCreation(
      booking: result.booking.toEntity(),
      payment: result.payment?.toEntity(),
    );
  });

  @override
  ResultFuture<List<Booking>> listMyBookings({String? status}) =>
      _guard('listMyBookings', () async {
        final models = await _remote.listMyBookings(status: status);
        return models.map((m) => m.toEntity()).toList(growable: false);
      });

  @override
  ResultFuture<Booking> getBooking(String bookingId) =>
      _guard('getBooking', () async {
        final model = await _remote.getBooking(bookingId);
        return model.toEntity();
      });

  @override
  ResultFuture<Booking> cancelBooking({
    required String bookingId,
    required String idempotencyKey,
    String? reasonCode,
    String? reason,
  }) => _guard('cancelBooking', () async {
    await _remote.cancelBooking(
      bookingId: bookingId,
      idempotencyKey: idempotencyKey,
      reasonCode: reasonCode,
      reason: reason,
    );
    final refreshed = await _remote.getBooking(bookingId);
    return refreshed.toEntity();
  });

  @override
  ResultFuture<PaymentRefreshResult> refreshPayment(String paymentId) =>
      _guard('refreshPayment', () async {
        final result = await _remote.refreshPayment(paymentId);
        return PaymentRefreshResult(
          paymentStatus: result.paymentStatus,
          bookingStatus: BookingStatus.fromWire(result.bookingStatus),
          refreshedFromProvider: result.refreshed,
        );
      });

  @override
  ResultFuture<List<PaymentInfo>> listBookingPayments(String bookingId) =>
      _guard('listBookingPayments', () async {
        final models = await _remote.listBookingPayments(bookingId);
        return models.map((m) => m.toEntity()).toList(growable: false);
      });

  Future<Either<Failure, T>> _guard<T>(
    String label,
    Future<T> Function() action,
  ) async {
    try {
      return Right(await action());
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, label));
    }
  }
}
