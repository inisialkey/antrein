import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';

abstract class QueueRepository {
  /// Check in a confirmed booking (§64). Backend enforces the window/eligibility.
  ResultFuture<QueueEntry> checkIn({
    required String bookingId,
    required String idempotencyKey,
  });

  /// The customer's own queue position (§81).
  ResultFuture<QueueEntry> getQueue(String bookingId);
}
