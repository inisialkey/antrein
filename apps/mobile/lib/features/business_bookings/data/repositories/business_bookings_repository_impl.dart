import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/booking.dart';
import 'package:antrein/features/business_bookings/data/datasources/business_bookings_remote_data_source.dart';
import 'package:antrein/features/business_bookings/domain/repositories/business_bookings_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BusinessBookingsRepository)
class BusinessBookingsRepositoryImpl implements BusinessBookingsRepository {
  const BusinessBookingsRepositoryImpl(this._remote);

  final BusinessBookingsRemoteDataSource _remote;

  @override
  ResultFuture<List<Booking>> list({
    required String businessId,
    required String outletId,
    required String date,
  }) => _guard('list', () async {
    final models = await _remote.list(
      businessId: businessId,
      outletId: outletId,
      date: date,
    );
    return models.map((m) => m.toEntity()).toList();
  });

  @override
  ResultVoid confirmPayAtLocation({
    required String businessId,
    required String bookingId,
    required Money amount,
    required String method,
    required String idempotencyKey,
    String? note,
  }) => _guard(
    'confirmPayAtLocation',
    () => _remote.confirmPayAtLocation(
      businessId: businessId,
      bookingId: bookingId,
      amount: amount,
      method: method,
      idempotencyKey: idempotencyKey,
      note: note,
    ),
  );

  @override
  ResultVoid cancel({
    required String businessId,
    required String bookingId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  }) => _guard(
    'cancel',
    () => _remote.cancel(
      businessId: businessId,
      bookingId: bookingId,
      reasonCode: reasonCode,
      reason: reason,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  ResultVoid markNoShow({
    required String businessId,
    required String bookingId,
    required String idempotencyKey,
    String? reason,
  }) => _guard(
    'markNoShow',
    () => _remote.markNoShow(
      businessId: businessId,
      bookingId: bookingId,
      idempotencyKey: idempotencyKey,
      reason: reason,
    ),
  );

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

  @override
  ResultFuture<List<PaymentInfo>> listPayments(String bookingId) =>
      _guard('listPayments', () async {
        final models = await _remote.listPayments(bookingId);
        return models.map((m) => m.toEntity()).toList();
      });

  @override
  ResultVoid requestRefund({
    required String businessId,
    required String paymentId,
    required Money amount,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  }) => _guard(
    'requestRefund',
    () => _remote.requestRefund(
      businessId: businessId,
      paymentId: paymentId,
      amount: amount,
      reasonCode: reasonCode,
      reason: reason,
      idempotencyKey: idempotencyKey,
    ),
  );
}
