import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';

/// Staff-facing queue operations (contract §82–§89). Reads the outlet board and
/// applies versioned lifecycle commands; the caller re-reads the board after a
/// command since REST is authoritative.
abstract interface class BusinessQueueRepository {
  ResultFuture<QueueBoard> getBoard({
    required String businessId,
    required String outletId,
    String? date,
  });

  ResultVoid runCommand({
    required String businessId,
    required String queueEntryId,
    required QueueCommand command,
    required int expectedVersion,
    required String idempotencyKey,
    String? reason,
    String? staffId,
  });

  /// The outlet whose queue this member manages: their first assigned outlet,
  /// or — for owners, who carry no `outletIds` — the business's primary outlet.
  ResultFuture<String> resolveOutletId({
    required String businessId,
    required List<String> membershipOutletIds,
  });
}
