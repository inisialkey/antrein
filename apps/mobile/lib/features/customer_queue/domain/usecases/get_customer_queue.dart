import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/repositories/queue_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetCustomerQueue extends UseCase<QueueEntry, GetCustomerQueueParams> {
  const GetCustomerQueue(this._repository);

  final QueueRepository _repository;

  @override
  ResultFuture<QueueEntry> call(GetCustomerQueueParams params) =>
      _repository.getQueue(params.bookingId);
}

class GetCustomerQueueParams extends Equatable {
  const GetCustomerQueueParams({required this.bookingId});

  final String bookingId;

  @override
  List<Object?> get props => [bookingId];
}
