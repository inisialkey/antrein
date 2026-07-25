import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class CreateBooking extends UseCase<BookingCreation, CreateBookingParams> {
  const CreateBooking(this._repository);

  final BookingRepository _repository;

  @override
  ResultFuture<BookingCreation> call(CreateBookingParams params) =>
      _repository.createBooking(
        businessId: params.businessId,
        outletId: params.outletId,
        serviceId: params.serviceId,
        staffId: params.staffId,
        scheduledAt: params.scheduledAt,
        paymentOption: params.paymentOption,
        idempotencyKey: params.idempotencyKey,
        notes: params.notes,
      );
}

class CreateBookingParams extends Equatable {
  const CreateBookingParams({
    required this.businessId,
    required this.outletId,
    required this.serviceId,
    required this.staffId,
    required this.scheduledAt,
    required this.paymentOption,
    required this.idempotencyKey,
    this.notes,
  });

  final String businessId;
  final String outletId;
  final String serviceId;
  final String staffId;
  final DateTime scheduledAt;
  final String paymentOption;

  /// Created when the logical submission begins; kept across retries
  /// (backend idempotency contract §23).
  final String idempotencyKey;
  final String? notes;

  @override
  List<Object?> get props => [
    businessId,
    outletId,
    serviceId,
    staffId,
    scheduledAt,
    paymentOption,
    idempotencyKey,
    notes,
  ];
}
