import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/customer_queue/data/datasources/queue_remote_data_source.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/repositories/queue_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: QueueRepository)
class QueueRepositoryImpl implements QueueRepository {
  const QueueRepositoryImpl(this._remote);

  final QueueRemoteDataSource _remote;

  @override
  ResultFuture<QueueEntry> checkIn({
    required String bookingId,
    required String idempotencyKey,
  }) => _guard('checkIn', () async {
    final model = await _remote.checkIn(
      bookingId: bookingId,
      idempotencyKey: idempotencyKey,
    );
    return model.toEntity();
  });

  @override
  ResultFuture<QueueEntry> getQueue(String bookingId) =>
      _guard('getQueue', () async {
        final model = await _remote.getQueue(bookingId);
        return model.toEntity();
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
