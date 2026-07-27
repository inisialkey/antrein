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

  /// Creates a walk-in booking + queue entry (§67) and returns the assigned
  /// display number (e.g. `A014`).
  ResultFuture<String> createWalkIn({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String customerName,
    required String idempotencyKey,
    String? phoneNumber,
  });

  /// Reorders the outlet queue (§90). [orderedQueueEntryIds] must be exactly
  /// the current waiting+skipped set; [expectedQueueVersion] is the board's
  /// aggregate version.
  ResultVoid reorderQueue({
    required String businessId,
    required String outletId,
    required String businessDate,
    required int expectedQueueVersion,
    required List<String> orderedQueueEntryIds,
    required String reason,
    required String idempotencyKey,
  });

  /// The outlet whose queue this member manages: their first assigned outlet,
  /// or — for owners, who carry no `outletIds` — the business's primary outlet.
  ResultFuture<String> resolveOutletId({
    required String businessId,
    required List<String> membershipOutletIds,
  });
}
