import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/repositories/queue_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class CheckIn extends UseCase<QueueEntry, CheckInParams> {
  const CheckIn(this._repository);

  final QueueRepository _repository;

  @override
  ResultFuture<QueueEntry> call(CheckInParams params) => _repository.checkIn(
    bookingId: params.bookingId,
    idempotencyKey: params.idempotencyKey,
  );
}

class CheckInParams extends Equatable {
  const CheckInParams({required this.bookingId, required this.idempotencyKey});

  final String bookingId;
  final String idempotencyKey;

  @override
  List<Object?> get props => [bookingId, idempotencyKey];
}
