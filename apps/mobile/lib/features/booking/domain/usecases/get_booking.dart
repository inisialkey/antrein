import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetBooking extends UseCase<Booking, GetBookingParams> {
  const GetBooking(this._repository);

  final BookingRepository _repository;

  @override
  ResultFuture<Booking> call(GetBookingParams params) =>
      _repository.getBooking(params.bookingId);
}

class GetBookingParams extends Equatable {
  const GetBookingParams({required this.bookingId});

  final String bookingId;

  @override
  List<Object?> get props => [bookingId];
}
