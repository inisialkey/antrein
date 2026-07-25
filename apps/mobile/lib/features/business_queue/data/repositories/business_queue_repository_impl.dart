import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/business_queue/data/datasources/business_queue_remote_data_source.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:antrein/features/business_queue/domain/repositories/business_queue_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BusinessQueueRepository)
class BusinessQueueRepositoryImpl implements BusinessQueueRepository {
  const BusinessQueueRepositoryImpl(this._remote);

  final BusinessQueueRemoteDataSource _remote;

  @override
  ResultFuture<QueueBoard> getBoard({
    required String businessId,
    required String outletId,
    String? date,
  }) => _guard('getBoard', () async {
    final model = await _remote.getBoard(businessId, outletId, date: date);
    return model.toEntity();
  });

  @override
  ResultVoid runCommand({
    required String businessId,
    required String queueEntryId,
    required QueueCommand command,
    required int expectedVersion,
    required String idempotencyKey,
    String? reason,
    String? staffId,
  }) => _guard('runCommand', () async {
    await _remote.runCommand(
      businessId: businessId,
      queueEntryId: queueEntryId,
      command: command,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      reason: reason,
      staffId: staffId,
    );
  });

  @override
  ResultFuture<String> resolveOutletId({
    required String businessId,
    required List<String> membershipOutletIds,
  }) => _guard('resolveOutletId', () async {
    if (membershipOutletIds.isNotEmpty) return membershipOutletIds.first;
    return _remote.primaryOutletId(businessId);
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
