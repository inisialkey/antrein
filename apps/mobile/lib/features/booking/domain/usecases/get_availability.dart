import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetAvailability extends UseCase<List<Slot>, GetAvailabilityParams> {
  const GetAvailability(this._repository);

  final BookingRepository _repository;

  @override
  ResultFuture<List<Slot>> call(GetAvailabilityParams params) =>
      _repository.getAvailability(
        businessId: params.businessId,
        outletId: params.outletId,
        serviceId: params.serviceId,
        staffId: params.staffId,
        date: params.date,
      );
}

class GetAvailabilityParams extends Equatable {
  const GetAvailabilityParams({
    required this.businessId,
    required this.outletId,
    required this.serviceId,
    required this.staffId,
    required this.date,
  });

  final String businessId;
  final String outletId;
  final String serviceId;
  final String staffId;

  /// `YYYY-MM-DD` in the outlet timezone (Asia/Jakarta).
  final String date;

  @override
  List<Object?> get props => [businessId, outletId, serviceId, staffId, date];
}
