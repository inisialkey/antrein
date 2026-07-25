import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class CancelBooking extends UseCase<Booking, CancelBookingParams> {
  const CancelBooking(this._repository);

  final BookingRepository _repository;

  @override
  ResultFuture<Booking> call(CancelBookingParams params) =>
      _repository.cancelBooking(
        bookingId: params.bookingId,
        idempotencyKey: params.idempotencyKey,
        reasonCode: params.reasonCode,
        reason: params.reason,
      );
}

class CancelBookingParams extends Equatable {
  const CancelBookingParams({
    required this.bookingId,
    required this.idempotencyKey,
    this.reasonCode,
    this.reason,
  });

  final String bookingId;
  final String idempotencyKey;
  final String? reasonCode;
  final String? reason;

  @override
  List<Object?> get props => [bookingId, idempotencyKey, reasonCode, reason];
}
