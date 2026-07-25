import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetMyBookings extends UseCase<List<Booking>, GetMyBookingsParams> {
  const GetMyBookings(this._repository);

  final BookingRepository _repository;

  @override
  ResultFuture<List<Booking>> call(GetMyBookingsParams params) =>
      _repository.listMyBookings(status: params.status);
}

class GetMyBookingsParams extends Equatable {
  const GetMyBookingsParams({this.status});

  final String? status;

  @override
  List<Object?> get props => [status];
}
